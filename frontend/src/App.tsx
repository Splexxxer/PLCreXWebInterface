import './index.css'

type UpcomingItem = {
  title: string
  detail: string
}

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
