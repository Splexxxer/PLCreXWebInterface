import { useCallback, useEffect, useState } from 'react'

import './index.css'

type UpcomingItem = {
  title: string
  detail: string
}

type PlcrexCommand = {
  name: string
  summary: string
  io?: string | null
}

type FetchState = 'idle' | 'loading' | 'success' | 'error'

const upcoming: UpcomingItem[] = [
  {
    title: 'Session-aware diagnostics',
    detail: 'Lightweight views that will read from sessionStorage once runtime wiring is in place.'
  },
  {
    title: 'PLCreX controls',
    detail: 'Trigger PLCreX runs through backend-managed processes without shipping the engine itself.'
  },
  {
    title: 'Packaging hooks',
    detail: 'Bake the built frontend, FastAPI backend, and PLCreX payload into a single container.'
  }
]

function App() {
  const [commands, setCommands] = useState<PlcrexCommand[]>([])
  const [commandState, setCommandState] = useState<FetchState>('idle')
  const [commandError, setCommandError] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<string>('')

  const fetchCommands = useCallback(async (refresh = false) => {
    setCommandState('loading')
    setCommandError(null)
    try {
      const url = refresh ? '/api/commands?refresh=true' : '/api/commands'
      const response = await fetch(url)
      if (!response.ok) {
        throw new Error('Unable to load PLCreX commands')
      }
      const data = (await response.json()) as PlcrexCommand[]
      setCommands(data)
      setCommandState('success')
      setLastUpdated(new Date().toLocaleTimeString())
    } catch (error) {
      setCommandState('error')
      setCommandError(error instanceof Error ? error.message : 'Unknown error while loading commands')
    }
  }, [])

  useEffect(() => {
    void fetchCommands()
  }, [fetchCommands])

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <main className="mx-auto flex min-h-screen max-w-4xl flex-col gap-10 px-6 py-12">
        <header>
          <p className="text-sm font-medium uppercase tracking-wide text-slate-500">
            PLCreX Web Interface
          </p>
          <h1 className="mt-2 text-3xl font-semibold text-slate-900">
            Minimal React starter for the PLCreX runtime console
          </h1>
          <p className="mt-3 text-base text-slate-600">
            This page is intentionally bare-bones. React, TypeScript, Tailwind, and Vite are wired up
            so future work can focus on the PLCreX user experience while FastAPI serves the built
            assets.
          </p>
        </header>

        <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-xl font-semibold text-slate-900">Available PLCreX commands</h2>
              <p className="text-sm text-slate-600">
                Commands are read dynamically from <code>plcrex --help</code> so UI controls stay in sync with
                the locally pulled PLCreX version.
              </p>
            </div>
            <button
              className="rounded-md border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-60"
              onClick={() => {
                void fetchCommands(true)
              }}
              disabled={commandState === 'loading'}
            >
              {commandState === 'loading' ? 'Refreshing…' : 'Refresh commands'}
            </button>
          </div>

          <div className="mt-4 text-xs text-slate-500">
            {commandState === 'success' && lastUpdated && <span>Last updated at {lastUpdated}</span>}
            {commandState === 'error' && commandError && (
              <span className="text-red-600">{commandError}</span>
            )}
            {commandState === 'loading' && (
              <span>{lastUpdated ? 'Refreshing command catalog…' : 'Loading command catalog…'}</span>
            )}
          </div>

          <ul className="mt-6 divide-y divide-slate-100 rounded-lg border border-slate-200 bg-slate-50">
            {commands.map((command) => (
              <li key={command.name} className="flex flex-col gap-1 px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="font-semibold text-slate-900">{command.name}</p>
                  <p className="text-slate-600">{command.summary || 'No summary available'}</p>
                </div>
                {command.io && <p className="text-xs text-slate-500">{command.io}</p>}
              </li>
            ))}
            {commands.length === 0 && commandState !== 'loading' && (
              <li className="px-4 py-6 text-center text-sm text-slate-500">
                No commands detected yet. Ensure PLCreX is available locally and try refreshing.
              </li>
            )}
          </ul>
        </section>

        <section className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 className="text-xl font-semibold text-slate-900">Development checklist</h2>
          <p className="mt-1 text-sm text-slate-600">
            Run the backend and frontend dev servers independently for now. The backend will later
            proxy the built frontend bundle.
          </p>
          <ul className="mt-6 space-y-4">
            {upcoming.map((item) => (
              <li key={item.title} className="rounded-lg border border-slate-100 bg-slate-50 p-4">
                <p className="text-sm font-semibold text-slate-800">{item.title}</p>
                <p className="mt-1 text-sm text-slate-600">{item.detail}</p>
              </li>
            ))}
          </ul>
        </section>

        <footer className="mt-auto text-xs text-slate-500">
          FastAPI will serve this bundle from <code>frontend/dist</code> after running the Vite build.
        </footer>
      </main>
    </div>
  )
}

export default App
