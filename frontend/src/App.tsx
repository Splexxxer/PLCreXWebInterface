import { useCallback, useEffect, useState } from 'react'

import './index.css'

type PlcrexCommand = {
  name: string
  summary: string
  io?: string | null
}

type FetchState = 'idle' | 'loading' | 'success' | 'error'

function App() {
  const [commands, setCommands] = useState<PlcrexCommand[]>([])
  const [commandState, setCommandState] = useState<FetchState>('idle')
  const [commandError, setCommandError] = useState<string | null>(null)

  const fetchCommands = useCallback(async () => {
    setCommandState('loading')
    setCommandError(null)
    try {
      const response = await fetch('/api/commands')
      if (!response.ok) {
        throw new Error('Unable to load PLCreX commands')
      }
      const data = (await response.json()) as PlcrexCommand[]
      setCommands(data)
      setCommandState('success')
    } catch (error) {
      setCommandState('error')
      setCommandError(error instanceof Error ? error.message : 'Unknown error while loading commands')
    }
  }, [])

  useEffect(() => {
    void fetchCommands()
  }, [fetchCommands])

  return (
    <div className="min-h-screen bg-[radial-gradient(circle_at_top,_#f8fbff_0%,_#ecf3ff_45%,_#dbe7f5_100%)] text-slate-950">
      <main className="mx-auto flex min-h-screen w-full max-w-7xl flex-col px-6 py-10 sm:px-8 lg:px-12">
        <header className="border-b border-slate-300/70 pb-8">
          <p className="text-xs font-semibold uppercase tracking-[0.45em] text-slate-500">Command Catalog</p>
          <h1 className="mt-3 font-['Space_Grotesk',_'Segoe_UI',_sans-serif] text-5xl font-bold tracking-tight text-slate-950 sm:text-6xl">
            PLCreX
          </h1>
          <p className="mt-4 max-w-2xl text-sm leading-6 text-slate-600 sm:text-base">
            Available commands are discovered directly from the installed PLCreX runtime and rendered as a
            structured command board.
          </p>
        </header>

        <section className="flex-1 py-8">
          <div className="mb-6 flex items-center justify-between gap-4">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Available Commands</h2>
              <p className="text-sm text-slate-600">
                {commandState === 'success'
                  ? `${commands.length} command${commands.length === 1 ? '' : 's'} loaded`
                  : 'Loading commands from the PLCreX help output'}
              </p>
            </div>
            {commandState === 'loading' && (
              <div className="rounded-full border border-slate-300 bg-white/80 px-4 py-2 text-xs font-semibold uppercase tracking-[0.25em] text-slate-500">
                Loading
              </div>
            )}
          </div>

          {commandState === 'error' && (
            <div className="rounded-2xl border border-red-200 bg-red-50 px-5 py-4 text-sm text-red-700">
              {commandError ?? 'Unable to load PLCreX commands.'} Reload the page after fixing the backend
              connection.
            </div>
          )}

          {commandState !== 'error' && (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
              {commands.map((command) => (
                <article
                  key={command.name}
                  className="flex min-h-48 flex-col rounded-3xl border border-slate-300/70 bg-white/90 p-5 shadow-[0_18px_45px_rgba(15,23,42,0.08)] backdrop-blur"
                >
                  <div className="flex items-start justify-between gap-3">
                    <h3 className="text-lg font-semibold leading-6 text-slate-950">{command.name}</h3>
                    <span className="rounded-full bg-slate-950 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.25em] text-white">
                      PLCreX
                    </span>
                  </div>

                  <p className="mt-4 flex-1 text-sm leading-6 text-slate-600">
                    {command.summary || 'No summary available.'}
                  </p>

                  <div className="mt-5 border-t border-slate-200 pt-4">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-400">IO</p>
                    <p className="mt-2 text-sm font-medium text-slate-700">{command.io || 'Not specified'}</p>
                  </div>
                </article>
              ))}

              {commandState === 'loading' &&
                Array.from({ length: 6 }).map((_, index) => (
                  <div
                    key={`skeleton-${index}`}
                    className="min-h-48 animate-pulse rounded-3xl border border-slate-200 bg-white/70 p-5"
                  >
                    <div className="h-5 w-32 rounded bg-slate-200" />
                    <div className="mt-4 h-4 w-full rounded bg-slate-100" />
                    <div className="mt-2 h-4 w-4/5 rounded bg-slate-100" />
                    <div className="mt-10 h-3 w-12 rounded bg-slate-200" />
                    <div className="mt-3 h-4 w-24 rounded bg-slate-100" />
                  </div>
                ))}
            </div>
          )}
        </section>
      </main>
    </div>
  )
}

export default App
