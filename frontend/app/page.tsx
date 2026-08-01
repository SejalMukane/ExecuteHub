import React from 'react';
import Link from 'next/link';
import { ArrowRight, ExternalLink, Box, Globe, GitBranch, Cpu } from 'lucide-react';

const features = [
  {
    icon: Box,
    title: "Docker Isolation",
    desc: "Every session runs in a fresh, ephemeral container ensuring zero state bleed or cache conflicts between runs.",
  },
  {
    icon: Globe,
    title: "Kubernetes Backed",
    desc: "Automatically scales compute nodes based on real-time browser session demand using robust EKS clusters.",
  },
  {
    icon: GitBranch,
    title: "Redis Queueing",
    desc: "High-throughput reservation system prevents node overload during sudden concurrent traffic spikes.",
  },
  {
    icon: Cpu,
    title: "Native Protocols",
    desc: "Connect instantly using standard Puppeteer, Playwright, or Selenium CDP endpoints without extra tooling.",
  },
];

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-black text-white font-sans selection:bg-white selection:text-black relative overflow-hidden">
      
      {/* Dot grid background */}
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.03]"
        style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, white 1px, transparent 0)`,
          backgroundSize: "40px 40px",
        }}
      />
      
      {/* Ambient glow */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[500px] bg-neutral-800/20 rounded-full blur-3xl pointer-events-none" />
      
      <div className="max-w-7xl mx-auto px-6 relative z-10">
        
        {/* Sticky Header with glass effect */}
        <header className="h-16 sticky top-0 z-50 flex justify-between items-center border-b border-neutral-900 bg-black/80 backdrop-blur-md">
          <span className="font-bold tracking-tight text-base">BrowserCloud</span>
          <div className="flex items-center gap-6">
            <Link href="/login" className="text-sm text-neutral-400 hover:text-white transition-colors">
              Sign in
            </Link>
            <a href="https://github.com" target="_blank" rel="noreferrer" className="text-neutral-400 hover:text-white transition-colors">
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M15 22v-4a4.8 4.8 0 0 0-1-3.02c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A4.8 4.8 0 0 0 8 18v4"/></svg>
            </a>
          </div>
        </header>

        {/* Hero Section */}
        <main className="py-24">
          <div className="flex flex-col items-start text-left max-w-2xl">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-neutral-800 bg-neutral-900/50 text-neutral-300 text-xs font-medium mb-8">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
              v1.0 — live infrastructure
            </div>
            
            <h1 className="text-4xl sm:text-6xl font-bold tracking-tight mb-6 leading-[1.05]">
              Headless browsers. <br />
              <span className="bg-gradient-to-r from-neutral-100 to-neutral-500 bg-clip-text text-transparent">
                Zero infrastructure.
              </span>
            </h1>
            
            <p className="text-base sm:text-lg text-neutral-400 mb-10 leading-relaxed max-w-xl">
              A cloud-native orchestrator that provisions ephemeral browser sessions through a simple REST API. Connect via WebSocket in milliseconds.
            </p>
            
            <div className="flex flex-wrap items-center gap-4">
              <Link href="/register" className="px-5 py-2.5 bg-white text-black text-sm font-medium rounded-md hover:bg-neutral-200 hover:scale-[1.02] active:scale-[0.98] transition-all shadow-lg shadow-white/10 inline-flex items-center">
                Get Started <ArrowRight className="w-4 h-4 ml-1" />
              </Link>
              <a href="#docs" className="text-sm font-medium text-neutral-400 hover:text-white transition-colors flex items-center gap-1 group">
                Read the docs <ExternalLink className="w-3.5 h-3.5 group-hover:translate-x-0.5 transition-transform" />
              </a>
            </div>
          </div>

          {/* Architecture Feature Grid */}
          <div className="mt-32 pt-20 border-t border-neutral-900">
            <div className="mb-12">
              <p className="text-xs text-neutral-500 uppercase tracking-wider font-semibold mb-2">Architecture</p>
              <h2 className="text-2xl font-semibold tracking-tight">Engineered for speed and isolation.</h2>
            </div>
            
            <div className="grid md:grid-cols-2 gap-5">
              {features.map((feature) => {
                const Icon = feature.icon;
                return (
                  <div
                    key={feature.title}
                    className="group relative p-6 rounded-xl border border-neutral-900 bg-neutral-950/50 hover:bg-neutral-900/30 hover:border-neutral-700 transition-all"
                  >
                    <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-neutral-800/0 to-neutral-800/0 group-hover:from-neutral-800/10 group-hover:to-neutral-800/0 transition-all pointer-events-none" />
                    <div className="relative">
                      <Icon className="w-5 h-5 text-neutral-500 mb-3" />
                      <h3 className="text-sm font-semibold text-white mb-2">{feature.title}</h3>
                      <p className="text-xs text-neutral-400 leading-relaxed">{feature.desc}</p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </main>

        {/* Footer */}
        <footer className="py-8 border-t border-neutral-900 text-xs text-neutral-500 flex justify-between items-center">
          <span>&copy; BrowserCloud</span>
          <div className="space-x-6">
            <a href="#" className="hover:text-neutral-300 transition-colors">Docs</a>
            <a href="#" className="hover:text-neutral-300 transition-colors">Status</a>
          </div>
        </footer>
        
      </div>
    </div>
  );
}
