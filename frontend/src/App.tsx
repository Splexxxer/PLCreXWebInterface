import { useEffect, useRef, useState } from 'react'
import type { ChangeEvent, DragEvent, FormEvent } from 'react'

import './index.css'

type PlcrexOption = {
  name: string
  label: string
  description: string
  default: boolean
}

type PlcrexCommand = {
  name: string
  summary: string
  io?: string | null
  accepts_upload: boolean
  accepts_text_input: boolean
  accepted_extensions: string[]
  output_extensions: string[]
  extra_path_label?: string | null
  extra_path_placeholder?: string | null
  text_input_label?: string | null
  text_input_placeholder?: string | null
  unsupported_reason?: string | null
  options: PlcrexOption[]
}

type PlcrexOutput = {
  filename: string
  content: string
}

type RunResult = {
  command: string
  filename?: string | null
  status: 'success' | 'error'
  stdout: string
  stderr: string
  outputs: PlcrexOutput[]
  message?: string
}

type HistoryEntry = {
  id: string
  command: string
  filename: string
  timestamp: string
  status: 'success' | 'error'
  message: string
}

type FetchState = 'idle' | 'loading' | 'success' | 'error'

const HISTORY_STORAGE_KEY = 'plcrex-history'

function readHistory(): HistoryEntry[] {
  const raw = sessionStorage.getItem(HISTORY_STORAGE_KEY)
  if (!raw) {
    return []
  }

  try {
    const parsed = JSON.parse(raw) as HistoryEntry[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

function persistHistory(entries: HistoryEntry[]) {
  sessionStorage.setItem(HISTORY_STORAGE_KEY, JSON.stringify(entries))
}

function inferAcceptValue(command: PlcrexCommand) {
  return command.accepted_extensions.join(',')
}

function summarizeResult(result: RunResult) {
  if (result.status === 'error') {
    return result.message ?? result.stderr ?? result.stdout ?? 'PLCreX returned an error.'
  }
  if (result.outputs.length > 0) {
    return `${result.outputs.length} output file${result.outputs.length === 1 ? '' : 's'} generated`
  }
  return 'PLCreX finished without generated files.'
}

function formatTimestamp(timestamp: string) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(timestamp))
}

function downloadOutput(output: PlcrexOutput) {
  const blob = new Blob([output.content], { type: 'text/plain;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = output.filename
  anchor.click()
  URL.revokeObjectURL(url)
}

function getRenderedOutputs(result: RunResult): PlcrexOutput[] {
  if (result.outputs.length > 0) {
    return result.outputs
  }
  if (result.stdout.trim()) {
    return [
      {
        filename: 'stdout.txt',
        content: result.stdout,
      },
    ]
  }
  return []
}

function LatestResultPanel({ result }: { result: RunResult | null }) {
  const renderedOutputs = result ? getRenderedOutputs(result) : []

  return (
    <section className="rounded-[2rem] border border-stone-300/70 bg-[linear-gradient(135deg,_rgba(255,255,255,0.82),_rgba(245,240,232,0.92))] p-6 shadow-[0_18px_45px_rgba(68,64,60,0.08)]">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.35em] text-stone-500">Latest Result</p>
          <h2 className="mt-2 text-2xl font-semibold text-stone-950">
            {result ? `${result.command} ${result.status}` : 'No command run yet'}
          </h2>
        </div>
        {result && (
          <span
            className={`rounded-full px-4 py-2 text-xs font-semibold uppercase tracking-[0.25em] ${
              result.status === 'success' ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-700'
            }`}
          >
            {result.status}
          </span>
        )}
      </div>

      {!result && (
        <p className="mt-4 text-sm leading-6 text-stone-600">
          Pick a command from the grid above. After PLCreX finishes, generated files and error output appear here.
        </p>
      )}

      {result && (
        <div className="mt-6 space-y-5">
          <div className="grid gap-4 md:grid-cols-2">
            <div className="rounded-[1.5rem] border border-stone-200 bg-white/80 p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-stone-500">Input</p>
              <p className="mt-2 text-sm font-medium text-stone-800">{result.filename ?? 'n/a'}</p>
            </div>
            <div className="rounded-[1.5rem] border border-stone-200 bg-white/80 p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-stone-500">Summary</p>
              <p className="mt-2 text-sm font-medium text-stone-800">{summarizeResult(result)}</p>
            </div>
          </div>

          {renderedOutputs.length > 0 && (
            <div className="space-y-4">
              {renderedOutputs.map((output) => (
                <article key={output.filename} className="rounded-[1.5rem] border border-stone-200 bg-white/85 p-4">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-stone-500">
                        {result.outputs.length > 0 ? 'Generated File' : 'Standard Output'}
                      </p>
                      <h3 className="mt-2 text-base font-semibold text-stone-900">{output.filename}</h3>
                    </div>
                    <button
                      type="button"
                      onClick={() => downloadOutput(output)}
                      className="rounded-full border border-stone-300 bg-stone-950 px-4 py-2 text-xs font-semibold uppercase tracking-[0.2em] text-stone-50 transition hover:-translate-y-0.5 hover:bg-stone-800"
                    >
                      Download
                    </button>
                  </div>
                  <pre className="mt-4 max-h-[34rem] overflow-auto rounded-[1.25rem] bg-stone-950 p-5 text-sm leading-7 text-stone-100">
                    {output.content}
                  </pre>
                </article>
              ))}
            </div>
          )}

          {result.status === 'error' && result.message && (
            <article className="rounded-[1.5rem] border border-red-200 bg-red-50/90 p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-red-500">Message</p>
              <p className="mt-3 text-sm leading-6 text-red-700">{result.message}</p>
            </article>
          )}
        </div>
      )}
    </section>
  )
}

function App() {
  const [commands, setCommands] = useState<PlcrexCommand[]>([])
  const [commandState, setCommandState] = useState<FetchState>('idle')
  const [commandError, setCommandError] = useState<string | null>(null)
  const [selectedCommand, setSelectedCommand] = useState<PlcrexCommand | null>(null)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [textInput, setTextInput] = useState('')
  const [extraPath, setExtraPath] = useState('')
  const [optionValues, setOptionValues] = useState<Record<string, boolean>>({})
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [result, setResult] = useState<RunResult | null>(null)
  const [history, setHistory] = useState<HistoryEntry[]>([])
  const [runError, setRunError] = useState<string | null>(null)
  const [isDragActive, setIsDragActive] = useState(false)
  const fileInputRef = useRef<HTMLInputElement | null>(null)

  useEffect(() => {
    setHistory(readHistory())
  }, [])

  useEffect(() => {
    async function loadCommands() {
      setCommandState('loading')
      setCommandError(null)

      try {
        const response = await fetch('/api/commands')
        if (!response.ok) {
          throw new Error('Unable to load PLCreX commands.')
        }

        const data = (await response.json()) as PlcrexCommand[]
        setCommands(data)
        setCommandState('success')
      } catch (error) {
        setCommandState('error')
        setCommandError(error instanceof Error ? error.message : 'Unknown error while loading PLCreX commands.')
      }
    }

    void loadCommands()
  }, [])

  useEffect(() => {
    if (!selectedCommand) {
      setOptionValues({})
      return
    }

    const defaults = Object.fromEntries(selectedCommand.options.map((option) => [option.name, option.default]))
    setOptionValues(defaults)
    setSelectedFile(null)
    setTextInput('')
    setIsDragActive(false)
    setExtraPath('')
    setRunError(null)
  }, [selectedCommand])

  function openCommand(command: PlcrexCommand) {
    setSelectedCommand(command)
  }

  function closeModal() {
    if (isSubmitting) {
      return
    }
    setSelectedCommand(null)
    setSelectedFile(null)
    setTextInput('')
    setIsDragActive(false)
    setExtraPath('')
    setRunError(null)
  }

  function handleFileSelection(file: File | null) {
    setSelectedFile(file)
    setRunError(null)
  }

  function handleFileChange(event: ChangeEvent<HTMLInputElement>) {
    handleFileSelection(event.target.files?.[0] ?? null)
  }

  function handleDragEnter(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault()
    setIsDragActive(true)
  }

  function handleDragOver(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault()
    setIsDragActive(true)
  }

  function handleDragLeave(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault()
    if (event.currentTarget.contains(event.relatedTarget as Node | null)) {
      return
    }
    setIsDragActive(false)
  }

  function handleDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault()
    setIsDragActive(false)
    handleFileSelection(event.dataTransfer.files?.[0] ?? null)
  }

  function updateHistory(nextEntry: HistoryEntry) {
    setHistory((current) => {
      const next = [nextEntry, ...current].slice(0, 8)
      persistHistory(next)
      return next
    })
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    if (!selectedCommand) {
      return
    }

    if (selectedCommand.accepts_text_input) {
      if (!textInput.trim()) {
        setRunError('Enter a formula before running PLCreX.')
        return
      }
    } else if (!selectedFile) {
      setRunError('Choose a file before running PLCreX.')
      return
    }

    setIsSubmitting(true)
    setRunError(null)

    const formData = new FormData()
    formData.append('command', selectedCommand.name)
    if (selectedCommand.accepts_text_input) {
      formData.append('input_text', textInput.trim())
    } else if (selectedFile) {
      formData.append('file', selectedFile)
    }
    formData.append(
      'options',
      JSON.stringify(
        Object.entries(optionValues).map(([name, value]) => ({
          name,
          value,
        })),
      ),
    )

    if (selectedCommand.extra_path_label && extraPath.trim()) {
      formData.append('extra_path', extraPath.trim())
    }

    try {
      const response = await fetch('/api/run', {
        method: 'POST',
        body: formData,
      })

      const payload = (await response.json()) as RunResult | { detail?: RunResult | string }
      if (!response.ok) {
        const detail = typeof payload === 'object' && payload !== null && 'detail' in payload ? payload.detail : payload
        const errorResult: RunResult =
          typeof detail === 'object' && detail !== null
            ? (detail as RunResult)
            : {
                command: selectedCommand.name,
                filename: selectedCommand.accepts_text_input ? textInput.trim() : (selectedFile?.name ?? null),
                status: 'error',
                stdout: '',
                stderr: '',
                outputs: [],
                message: typeof detail === 'string' ? detail : 'PLCreX request failed.',
              }

        setResult(errorResult)
        updateHistory({
          id: crypto.randomUUID(),
          command: errorResult.command,
          filename: errorResult.filename ?? (selectedCommand.accepts_text_input ? textInput.trim() : (selectedFile?.name ?? 'input')),
          timestamp: new Date().toISOString(),
          status: 'error',
          message: summarizeResult(errorResult),
        })
        setRunError(summarizeResult(errorResult))
        return
      }

      const runResult = payload as RunResult
      setResult(runResult)
      updateHistory({
        id: crypto.randomUUID(),
        command: runResult.command,
        filename: runResult.filename ?? (selectedCommand.accepts_text_input ? textInput.trim() : (selectedFile?.name ?? 'input')),
        timestamp: new Date().toISOString(),
        status: runResult.status,
        message: summarizeResult(runResult),
      })
      closeModal()
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown PLCreX request failure.'
      setRunError(message)
      setResult({
        command: selectedCommand.name,
        filename: selectedCommand.accepts_text_input ? textInput.trim() : (selectedFile?.name ?? null),
        status: 'error',
        stdout: '',
        stderr: '',
        outputs: [],
        message,
      })
      updateHistory({
        id: crypto.randomUUID(),
        command: selectedCommand.name,
        filename: selectedCommand.accepts_text_input ? textInput.trim() : (selectedFile?.name ?? 'input'),
        timestamp: new Date().toISOString(),
        status: 'error',
        message,
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="min-h-screen bg-[linear-gradient(180deg,_#f4efe6_0%,_#ebe4d8_38%,_#d9d4c8_100%)] text-stone-950">
      <main className="mx-auto flex min-h-screen w-full max-w-7xl flex-col px-6 py-8 sm:px-8 lg:px-12">
        <header className="flex flex-col gap-6 border-b border-stone-400/40 pb-8 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.45em] text-stone-500">Single-Page Runtime</p>
            <h1 className="mt-3 font-['Space_Grotesk',_'Segoe_UI',_sans-serif] text-5xl font-bold tracking-tight text-stone-950 sm:text-6xl">
              PLCreX
            </h1>
            <p className="mt-4 max-w-3xl text-sm leading-6 text-stone-700 sm:text-base">
              Click a PLCreX command, upload the input file, and run it directly from this page. Results stay visible
              below and recent runs are kept in this browser session only.
            </p>
          </div>

          <div className="grid gap-3 rounded-[2rem] border border-stone-300/70 bg-white/60 px-5 py-4 shadow-[0_20px_50px_rgba(68,64,60,0.12)] backdrop-blur">
            <p className="text-[11px] font-semibold uppercase tracking-[0.3em] text-stone-500">Status</p>
            <p className="text-sm font-medium text-stone-800">
              {commandState === 'success'
                ? `${commands.length} command${commands.length === 1 ? '' : 's'} ready`
                : commandState === 'loading'
                  ? 'Loading PLCreX catalog'
                  : 'Waiting for PLCreX catalog'}
            </p>
            <div className="grid gap-3 border-t border-stone-300/70 pt-3">
              <a
                href="https://github.com/marwern/PLCreX"
                target="_blank"
                rel="noreferrer"
                className="rounded-2xl border border-stone-300 bg-white/80 px-4 py-3 text-sm font-semibold text-stone-800 shadow-[0_8px_18px_rgba(68,64,60,0.08)] transition hover:-translate-y-0.5 hover:border-stone-500 hover:bg-white hover:text-stone-950"
              >
                PLCreX Repository
              </a>
              <a
                href="https://plcrex.readthedocs.io/en/latest/"
                target="_blank"
                rel="noreferrer"
                className="rounded-2xl border border-stone-300 bg-white/80 px-4 py-3 text-sm font-semibold text-stone-800 shadow-[0_8px_18px_rgba(68,64,60,0.08)] transition hover:-translate-y-0.5 hover:border-stone-500 hover:bg-white hover:text-stone-950"
              >
                PLCreX Documentation
              </a>
            </div>
          </div>
        </header>

        <section className="grid flex-1 gap-8 py-8 xl:grid-cols-[minmax(0,2fr)_22rem]">
          <div className="space-y-8">
            {commandState === 'error' && (
              <div className="rounded-[1.75rem] border border-red-300 bg-red-50 px-5 py-4 text-sm text-red-700">
                {commandError ?? 'Unable to load PLCreX commands.'}
              </div>
            )}

            <section>
              <div className="mb-5 flex items-center justify-between gap-4">
                <div>
                  <h2 className="text-xl font-semibold text-stone-900">Commands</h2>
                  <p className="text-sm text-stone-600">Selecting a command opens the upload window for that workflow.</p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                {commands.map((command) => (
                  <button
                    key={command.name}
                    type="button"
                    onClick={() => openCommand(command)}
                    disabled={!command.accepts_upload && !command.accepts_text_input}
                    className="group flex min-h-52 flex-col rounded-[2rem] border border-stone-300/70 bg-white/80 p-5 text-left shadow-[0_18px_45px_rgba(68,64,60,0.1)] transition hover:-translate-y-0.5 hover:border-stone-500 hover:shadow-[0_24px_55px_rgba(68,64,60,0.16)] disabled:cursor-not-allowed disabled:opacity-55"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <h3 className="text-lg font-semibold leading-6 text-stone-950">{command.name}</h3>
                      <span className="rounded-full bg-stone-900 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.25em] text-stone-50">
                        {command.accepts_text_input
                          ? 'text'
                          : command.accepted_extensions.length > 0
                            ? command.accepted_extensions.join(' ')
                            : 'any'}
                      </span>
                    </div>

                    <p className="mt-4 flex-1 text-sm leading-6 text-stone-600">{command.summary || 'No summary available.'}</p>

                    <div className="mt-5 space-y-2 border-t border-stone-200 pt-4 text-xs text-stone-500">
                      <p className="font-semibold uppercase tracking-[0.2em]">Output</p>
                      <p className="text-sm font-medium text-stone-700">
                        {command.output_extensions.length > 0 ? command.output_extensions.join(', ') : 'stdout'}
                      </p>
                      {!command.accepts_upload && (
                        <p className="text-sm text-amber-700">{command.unsupported_reason ?? 'Upload flow not available.'}</p>
                      )}
                    </div>
                  </button>
                ))}

                {commandState === 'loading' &&
                  Array.from({ length: 6 }).map((_, index) => (
                    <div
                      key={`skeleton-${index}`}
                      className="min-h-52 animate-pulse rounded-[2rem] border border-stone-200 bg-white/60 p-5"
                    >
                      <div className="h-5 w-36 rounded bg-stone-200" />
                      <div className="mt-4 h-4 w-full rounded bg-stone-100" />
                      <div className="mt-2 h-4 w-5/6 rounded bg-stone-100" />
                      <div className="mt-10 h-4 w-20 rounded bg-stone-200" />
                    </div>
                  ))}
              </div>
            </section>

            <div className="xl:hidden">
              <LatestResultPanel result={result} />
            </div>
          </div>

          <aside className="rounded-[2rem] border border-stone-300/70 bg-white/75 p-5 shadow-[0_18px_45px_rgba(68,64,60,0.08)] backdrop-blur">
            <div className="flex items-center justify-between gap-4 border-b border-stone-200 pb-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.35em] text-stone-500">History</p>
                <h2 className="mt-2 text-xl font-semibold text-stone-950">Session Runs</h2>
              </div>
              <span className="rounded-full bg-stone-100 px-3 py-1 text-xs font-semibold text-stone-700">
                {history.length}
              </span>
            </div>

            <div className="mt-5 space-y-3">
              {history.length === 0 && (
                <p className="text-sm leading-6 text-stone-600">
                  Runs are stored in `sessionStorage` and disappear when this browser session ends.
                </p>
              )}

              {history.map((entry) => (
                <article key={entry.id} className="rounded-[1.5rem] border border-stone-200 bg-stone-50/80 p-4">
                  <div className="flex items-center justify-between gap-3">
                    <h3 className="text-sm font-semibold text-stone-900">{entry.command}</h3>
                    <span
                      className={`rounded-full px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] ${
                        entry.status === 'success' ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-700'
                      }`}
                    >
                      {entry.status}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-stone-700">{entry.filename}</p>
                  <p className="mt-2 text-xs leading-5 text-stone-500">{entry.message}</p>
                  <p className="mt-3 text-[11px] font-medium uppercase tracking-[0.15em] text-stone-400">
                    {formatTimestamp(entry.timestamp)}
                  </p>
                </article>
              ))}
            </div>
          </aside>
        </section>
      </main>

      <div className="pointer-events-none fixed inset-y-0 right-0 z-30 hidden w-[38rem] max-w-[86vw] items-start justify-end pr-4 pt-28 xl:flex">
        <div className="group pointer-events-auto relative flex h-[calc(100vh-8rem)] w-full max-w-[38rem] translate-x-[calc(100%-2.75rem)] transition-transform duration-300 ease-out hover:translate-x-0 focus-within:translate-x-0">
          <div className="absolute left-0 top-24 -translate-x-full">
            <div className="flex min-h-32 w-11 items-center justify-center rounded-l-[1.5rem] border border-r-0 border-stone-300/80 bg-white/85 px-2 shadow-[0_18px_45px_rgba(68,64,60,0.12)] backdrop-blur">
              <span className="-rotate-90 whitespace-nowrap text-[11px] font-semibold uppercase tracking-[0.3em] text-stone-600">
                Latest Result
              </span>
            </div>
          </div>
          <div className="h-full w-full overflow-y-auto rounded-[2rem] border border-stone-300/80 bg-[#f8f4ed]/95 p-3 shadow-[0_30px_80px_rgba(28,25,23,0.2)] backdrop-blur">
            <LatestResultPanel result={result} />
          </div>
        </div>
      </div>

      {selectedCommand && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-stone-950/45 px-4 py-8 backdrop-blur-sm">
          <div className="w-full max-w-2xl rounded-[2rem] border border-stone-300 bg-[linear-gradient(180deg,_#fffdfa_0%,_#f4eee4_100%)] p-6 shadow-[0_30px_80px_rgba(28,25,23,0.35)]">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.35em] text-stone-500">
                  {selectedCommand.accepts_text_input ? 'Input Window' : 'Upload Window'}
                </p>
                <h2 className="mt-2 text-3xl font-semibold text-stone-950">{selectedCommand.name}</h2>
                <p className="mt-3 text-sm leading-6 text-stone-600">{selectedCommand.summary}</p>
              </div>
              <button type="button" onClick={closeModal} className="rounded-full border border-stone-300 px-4 py-2 text-sm text-stone-700">
                Close
              </button>
            </div>

            <form className="mt-6 space-y-5" onSubmit={handleSubmit}>
              <div className="rounded-[1.5rem] border border-stone-200 bg-white/80 p-4">
                <label className="block text-[11px] font-semibold uppercase tracking-[0.25em] text-stone-500">
                  {selectedCommand.accepts_text_input ? (selectedCommand.text_input_label ?? 'Input Text') : 'Input File'}
                </label>
                {selectedCommand.accepts_text_input ? (
                  <>
                    <textarea
                      value={textInput}
                      onChange={(event) => {
                        setTextInput(event.target.value)
                        setRunError(null)
                      }}
                      placeholder={selectedCommand.text_input_placeholder ?? ''}
                      rows={6}
                      className="mt-3 w-full rounded-[1.5rem] border border-stone-300 bg-stone-50/80 px-4 py-4 text-sm leading-6 text-stone-800 outline-none placeholder:text-stone-400 focus:border-stone-500 focus:bg-white"
                    />
                    <p className="mt-3 text-xs text-stone-500">Enter the raw formula string expected by this PLCreX command.</p>
                  </>
                ) : (
                  <>
                    <label
                      onDragEnter={handleDragEnter}
                      onDragOver={handleDragOver}
                      onDragLeave={handleDragLeave}
                      onDrop={handleDrop}
                      className={`mt-3 flex cursor-pointer flex-col items-center justify-center rounded-[1.5rem] border border-dashed px-5 py-8 text-center transition ${
                        isDragActive
                          ? 'border-stone-950 bg-stone-950 text-stone-50 shadow-[0_18px_40px_rgba(28,25,23,0.22)]'
                          : 'border-stone-300 bg-stone-50/80 text-stone-700 hover:border-stone-500 hover:bg-white'
                      }`}
                    >
                      <input
                        ref={fileInputRef}
                        type="file"
                        accept={inferAcceptValue(selectedCommand)}
                        onChange={handleFileChange}
                        className="sr-only"
                      />
                      <span className="text-sm font-semibold uppercase tracking-[0.24em]">
                        {isDragActive ? 'Drop File Here' : 'Drag and Drop a File'}
                      </span>
                      <span className={`mt-3 text-sm ${isDragActive ? 'text-stone-200' : 'text-stone-500'}`}>
                        {selectedFile ? selectedFile.name : 'or choose a file from your computer'}
                      </span>
                      <span
                        className={`mt-5 rounded-full px-5 py-3 text-xs font-semibold uppercase tracking-[0.22em] transition ${
                          isDragActive
                            ? 'border border-stone-100 bg-stone-100 text-stone-950'
                            : 'border border-stone-950 bg-stone-950 text-stone-50 hover:-translate-y-0.5 hover:bg-stone-800'
                        }`}
                      >
                        Choose File
                      </span>
                    </label>
                    <p className="mt-3 text-xs text-stone-500">
                      Accepted: {selectedCommand.accepted_extensions.length > 0 ? selectedCommand.accepted_extensions.join(', ') : 'any'}
                    </p>
                  </>
                )}
              </div>

              {selectedCommand.extra_path_label && (
                <div className="rounded-[1.5rem] border border-stone-200 bg-white/80 p-4">
                  <label className="block text-[11px] font-semibold uppercase tracking-[0.25em] text-stone-500">
                    {selectedCommand.extra_path_label}
                  </label>
                  <input
                    value={extraPath}
                    onChange={(event) => setExtraPath(event.target.value)}
                    placeholder={selectedCommand.extra_path_placeholder ?? ''}
                    className="mt-3 w-full rounded-xl border border-stone-300 bg-white px-4 py-3 text-sm text-stone-800 outline-none ring-0 placeholder:text-stone-400"
                  />
                </div>
              )}

              {selectedCommand.options.length > 0 && (
                <div className="rounded-[1.5rem] border border-stone-200 bg-white/80 p-4">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.25em] text-stone-500">Options</p>
                  <div className="mt-4 grid gap-3">
                    {selectedCommand.options.map((option) => (
                      <label
                        key={option.name}
                        className="flex items-start gap-3 rounded-xl border border-stone-200 bg-stone-50/80 px-4 py-3"
                      >
                        <input
                          type="checkbox"
                          checked={Boolean(optionValues[option.name])}
                          onChange={(event) =>
                            setOptionValues((current) => ({
                              ...current,
                              [option.name]: event.target.checked,
                            }))
                          }
                          className="mt-1 h-4 w-4 rounded border-stone-300 text-stone-950"
                        />
                        <span>
                          <span className="block text-sm font-semibold text-stone-900">{option.label}</span>
                          <span className="mt-1 block text-sm text-stone-600">{option.description}</span>
                        </span>
                      </label>
                    ))}
                  </div>
                </div>
              )}

              {runError && <div className="rounded-[1.5rem] border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">{runError}</div>}

              <div className="flex flex-col gap-3 sm:flex-row sm:justify-end">
                <button
                  type="button"
                  onClick={closeModal}
                  className="rounded-full border border-stone-300 px-5 py-3 text-sm font-medium text-stone-700 transition hover:-translate-y-0.5 hover:border-stone-500 hover:bg-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="rounded-full bg-stone-950 px-6 py-3 text-sm font-semibold uppercase tracking-[0.2em] text-stone-50 transition hover:-translate-y-0.5 hover:bg-stone-800 disabled:opacity-60"
                >
                  {isSubmitting ? 'Running' : 'Run PLCreX'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default App
