import { useMemo, useState } from 'react';
import JSZip from 'jszip';
import { Check, Copy, Download, FileCode2, FolderTree, Map as MapIcon, Shield } from 'lucide-react';

const TEXT_MODULES = import.meta.glob('/godot_project/**/*.{godot,gd,tscn,gdshader,obj,svg,md}', {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>;

const PNG_MODULES = import.meta.glob('/godot_project/**/*.png', {
  query: '?url',
  import: 'default',
  eager: true,
}) as Record<string, string>;

type TabId = 'overview' | 'map' | 'files';

interface WeaponRow {
  name: string;
  slot: string;
  price: string;
  damage: string;
  headshot: string;
  mag: string;
  speed: string;
}

const WEAPONS: WeaponRow[] = [
  { name: 'AK-47', slot: 'Primary', price: '$2,700', damage: '37', headshot: '3.8x', mag: '30 / 90', speed: '5.45 m/s' },
  { name: 'M4A1-Carbine', slot: 'Primary', price: '$2,900', damage: '34', headshot: '3.3x', mag: '25 / 75', speed: '5.60 m/s' },
  { name: 'MP5-SD', slot: 'Primary', price: '$1,500', damage: '25', headshot: '2.7x', mag: '30 / 90', speed: '6.00 m/s' },
  { name: 'USP-Tactical', slot: 'Secondary', price: '$200', damage: '33', headshot: '3.4x', mag: '12 / 36', speed: '6.25 m/s' },
  { name: 'Glock-18C', slot: 'Secondary', price: '$200', damage: '27', headshot: '3.2x', mag: '20 / 60', speed: '6.35 m/s' },
  { name: 'HE Frag Grenade', slot: 'Utility', price: '$300', damage: '94', headshot: '1.0x', mag: '1 / 0', speed: '6.60 m/s' },
  { name: 'Tactical Knife', slot: 'Melee', price: '$0', damage: '55', headshot: '1.5x', mag: 'Melee', speed: '6.85 m/s' },
];

interface MapCallout {
  id: string;
  label: string;
  x: number;
  y: number;
  w: number;
  h: number;
  tone: string;
  detail: string;
  coords: string;
}

const CALLOUTS: MapCallout[] = [
  { id: 'CT', label: 'CT Spawn', x: 185, y: 24, w: 130, h: 46, tone: '#2563eb', detail: 'Counter-Terrorist pergola spawn with sandbag cover and fast rotations to both bombsites and Mid.', coords: 'X: -5..5, Z: -26.5' },
  { id: 'BBALC', label: 'B Balcony', x: 26, y: 54, w: 66, h: 42, tone: '#38bdf8', detail: 'Elevated Y=+2.0m overlook above Site B connected via a 45°-navigable ramp.', coords: 'X: -34.5, Y: 2.0, Z: -18.5' },
  { id: 'B', label: 'Site B', x: 36, y: 102, w: 120, h: 98, tone: '#0ea5e9', detail: 'West bombsite with hazard pad, sandstone pillar cover, crates, and elevated B Balcony flank.', coords: 'X: -24.0, Z: -8.0' },
  { id: 'MID', label: 'Mid Courtyard', x: 185, y: 118, w: 130, h: 124, tone: '#64748b', detail: 'Central duel courtyard with monument plinth, stacked crates, sandbag bunkers, and A-Short / B-Connector arches.', coords: 'X: 0.0, Z: 0.0' },
  { id: 'AHEAV', label: 'A Heaven', x: 408, y: 54, w: 66, h: 42, tone: '#fb923c', detail: 'Elevated Y=+2.0m parapet platform overlooking Site A with a walkable ramp from Long A.', coords: 'X: 34.5, Y: 2.0, Z: -18.5' },
  { id: 'A', label: 'Site A', x: 344, y: 102, w: 120, h: 98, tone: '#f59e0b', detail: 'East bombsite with hazard pad, double-stacked crates, barrels, and A Heaven high ground.', coords: 'X: 24.0, Z: -8.0' },
  { id: 'BTUN', label: 'B Tunnels', x: 36, y: 218, w: 120, h: 86, tone: '#475569', detail: 'West approach framed by corrugated metal panels and crate cover leading to Site B.', coords: 'X: -24.0, Z: 14.0' },
  { id: 'ALONG', label: 'Long A', x: 344, y: 218, w: 120, h: 86, tone: '#475569', detail: 'East approach under pergola beams with barrel and crate cover leading to Site A.', coords: 'X: 24.0, Z: 14.0' },
  { id: 'T', label: 'T Spawn', x: 185, y: 300, w: 130, h: 46, tone: '#d97706', detail: 'Terrorist pergola spawn with sandbag line and C4 carrier assigned to flank or site push.', coords: 'X: -5..5, Z: 26.5' },
];

export default function App() {
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const [isZipping, setIsZipping] = useState(false);
  const [selectedCallout, setSelectedCallout] = useState<MapCallout>(CALLOUTS[3]);
  const [copiedPath, setCopiedPath] = useState<string | null>(null);

  const allFiles = useMemo(() => {
    const entries: { path: string; kind: 'text' | 'png'; content?: string; url?: string }[] = [];
    for (const [fullPath, content] of Object.entries(TEXT_MODULES)) {
      entries.push({ path: fullPath.replace(/^\/godot_project\//, ''), kind: 'text', content });
    }
    for (const [fullPath, url] of Object.entries(PNG_MODULES)) {
      entries.push({ path: fullPath.replace(/^\/godot_project\//, ''), kind: 'png', url });
    }
    return entries.sort((a, b) => a.path.localeCompare(b.path));
  }, []);

  const [selectedFilePath, setSelectedFilePath] = useState<string>(() => {
    const first = allFiles.find((f) => f.path === 'project.godot') ?? allFiles[0];
    return first ? first.path : '';
  });

  const selectedFile = useMemo(
    () => allFiles.find((f) => f.path === selectedFilePath) ?? allFiles[0],
    [allFiles, selectedFilePath],
  );

  async function handleDownloadZip() {
    if (isZipping) return;
    setIsZipping(true);
    try {
      const zip = new JSZip();
      const folder = zip.folder('strikepoint_mobile_5v5');
      if (!folder) return;

      for (const f of allFiles) {
        if (f.kind === 'text' && typeof f.content === 'string') {
          folder.file(f.path, f.content);
        } else if (f.kind === 'png' && f.url) {
          const res = await fetch(f.url);
          const buf = await res.arrayBuffer();
          folder.file(f.path, buf);
        }
      }

      const blob = await zip.generateAsync({ type: 'blob' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'strikepoint_mobile_5v5_godot4.zip';
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } finally {
      setIsZipping(false);
    }
  }

  async function handleCopy(path: string, content: string) {
    await navigator.clipboard.writeText(content);
    setCopiedPath(path);
    setTimeout(() => setCopiedPath(null), 1600);
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      <header className="border-b border-slate-800 bg-slate-900/80 px-6 py-4 flex items-center justify-between gap-8">
        <span className="font-display text-lg font-bold tracking-tight text-slate-100 whitespace-nowrap shrink-0">
          StrikePoint Mobile 5v5
        </span>

        <nav className="flex items-center gap-6 text-sm font-medium text-slate-400">
          <button
            type="button"
            onClick={() => setActiveTab('overview')}
            className={`whitespace-nowrap shrink-0 transition-colors cursor-pointer pb-0.5 border-b-2 ${
              activeTab === 'overview'
                ? 'text-slate-100 border-amber-500'
                : 'border-transparent hover:text-slate-200'
            }`}
          >
            Overview
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('map')}
            className={`whitespace-nowrap shrink-0 transition-colors cursor-pointer pb-0.5 border-b-2 ${
              activeTab === 'map'
                ? 'text-slate-100 border-amber-500'
                : 'border-transparent hover:text-slate-200'
            }`}
          >
            Map Blueprint
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('files')}
            className={`whitespace-nowrap shrink-0 transition-colors cursor-pointer pb-0.5 border-b-2 ${
              activeTab === 'files'
                ? 'text-slate-100 border-amber-500'
                : 'border-transparent hover:text-slate-200'
            }`}
          >
            Project Files
          </button>
        </nav>

        <button
          type="button"
          onClick={handleDownloadZip}
          disabled={isZipping}
          className="inline-flex items-center gap-2 px-4 py-2 text-xs font-semibold text-slate-950 bg-amber-400 hover:bg-amber-300 disabled:opacity-60 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
        >
          <Download className="w-4 h-4" />
          {isZipping ? 'Packing Project...' : 'Download Godot (.zip)'}
        </button>
      </header>

      <main className="flex-1 w-full max-w-[1200px] mx-auto px-6 py-8">
        {activeTab === 'overview' && (
          <div className="space-y-10">
            <section className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start border-b border-slate-800 pb-8">
              <div className="lg:col-span-7 space-y-4">
                <p className="text-xs font-medium text-amber-400 tracking-wide">
                  Godot 4.3+ / 4.7 Mobile Project · {allFiles.length} Source &amp; Asset Files
                </p>
                <h1 className="font-display text-3xl sm:text-4xl font-bold tracking-tight text-slate-100 max-w-2xl [text-wrap:balance]">
                  Offline 5v5 tactical FPS built for Android touch and 60 FPS performance.
                </h1>
                <p className="text-slate-300 text-base leading-relaxed max-w-2xl">
                  Generated inside <code className="text-amber-300 text-sm">/godot_project</code> with sculpted Wavefront
                  character and weapon meshes across 4 operator archetypes, 512px PBR textures, purple/blue/yellow
                  zone lighting, 720p 3D scaling capped at 60 FPS, single-button 1st/2nd/3rd person POV switching, and
                  100% offline 5v5 AI bots.
                </p>
              </div>

              <div className="lg:col-span-5 bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
                <h2 className="font-display text-base font-semibold text-slate-100">
                  Import into Godot 4 on Android
                </h2>
                <ol className="space-y-2.5 text-sm text-slate-300">
                  <li>1. Push this repo to GitHub or tap <strong className="text-slate-100">Download Godot (.zip)</strong> above.</li>
                  <li>2. Extract or pull the <code className="text-amber-300">godot_project</code> folder onto your phone.</li>
                  <li>3. In Godot 4.7, tap <strong className="text-slate-100">Import</strong>, select <code className="text-amber-300">project.godot</code>, and press Play.</li>
                </ol>
              </div>
            </section>

            <section className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
                <p className="text-xs text-slate-400">Render Target</p>
                <p className="font-display text-lg font-semibold text-slate-100 mt-1 tabular-nums">720p Scale · 60 FPS</p>
              </div>
              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
                <p className="text-xs text-slate-400">Camera Modes</p>
                <p className="font-display text-lg font-semibold text-slate-100 mt-1">1st / 2nd / 3rd POV</p>
              </div>
              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
                <p className="text-xs text-slate-400">Arena Footprint</p>
                <p className="font-display text-lg font-semibold text-slate-100 mt-1 tabular-nums">78m × 66m</p>
              </div>
              <div className="bg-slate-900 border border-slate-800 rounded-xl p-4">
                <p className="text-xs text-slate-400">Offline 5v5</p>
                <p className="font-display text-lg font-semibold text-slate-100 mt-1">4 Classes · Zone Lights</p>
              </div>
            </section>

            <section className="space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="font-display text-xl font-semibold text-slate-100">
                  Weapon Balance &amp; Economy
                </h2>
                <span className="text-xs text-slate-400">Defined in scripts/weapon_data.gd</span>
              </div>

              <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead className="border-b border-slate-800 text-xs text-slate-400">
                    <tr>
                      <th className="py-3 px-4 font-medium">Weapon</th>
                      <th className="py-3 px-4 font-medium">Slot</th>
                      <th className="py-3 px-4 font-medium text-right">Price</th>
                      <th className="py-3 px-4 font-medium text-right">Body Dmg</th>
                      <th className="py-3 px-4 font-medium text-right">Head Mult</th>
                      <th className="py-3 px-4 font-medium text-right">Ammo</th>
                      <th className="py-3 px-4 font-medium text-right">Move Speed</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/80">
                    {WEAPONS.map((w) => (
                      <tr key={w.name} className="hover:bg-slate-800/40 transition-colors">
                        <td className="py-3 px-4 font-medium text-slate-100">{w.name}</td>
                        <td className="py-3 px-4 text-slate-400">{w.slot}</td>
                        <td className="py-3 px-4 text-right font-mono tabular-nums text-emerald-400">{w.price}</td>
                        <td className="py-3 px-4 text-right font-mono tabular-nums text-slate-200">{w.damage}</td>
                        <td className="py-3 px-4 text-right font-mono tabular-nums text-amber-400">{w.headshot}</td>
                        <td className="py-3 px-4 text-right font-mono tabular-nums text-slate-300">{w.mag}</td>
                        <td className="py-3 px-4 text-right font-mono tabular-nums text-slate-300">{w.speed}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        )}

        {activeTab === 'map' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            <div className="lg:col-span-7 bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="font-display text-lg font-semibold text-slate-100 flex items-center gap-2">
                  <MapIcon className="w-4 h-4 text-amber-400" />
                  Sandstone Yard — 3-Lane 5v5 Layout
                </h2>
                <span className="text-xs text-slate-400">Tap any zone to inspect</span>
              </div>

              <svg viewBox="0 0 500 370" className="w-full h-auto bg-slate-950 rounded-lg border border-slate-800">
                <rect x="20" y="16" width="460" height="338" rx="6" fill="#0b1220" stroke="#334155" strokeWidth="2" />
                {/* Lane dividers */}
                <rect x="164" y="84" width="12" height="90" fill="#334155" />
                <rect x="164" y="210" width="12" height="86" fill="#334155" />
                <rect x="324" y="84" width="12" height="90" fill="#334155" />
                <rect x="324" y="210" width="12" height="86" fill="#334155" />

                {CALLOUTS.map((zone) => {
                  const active = selectedCallout.id === zone.id;
                  return (
                    <g
                      key={zone.id}
                      onClick={() => setSelectedCallout(zone)}
                      className="cursor-pointer"
                    >
                      <rect
                        x={zone.x}
                        y={zone.y}
                        width={zone.w}
                        height={zone.h}
                        rx="6"
                        fill={zone.tone}
                        fillOpacity={active ? 0.34 : 0.16}
                        stroke={active ? '#f59e0b' : zone.tone}
                        strokeWidth={active ? 2.5 : 1.5}
                      />
                      <text
                        x={zone.x + zone.w / 2}
                        y={zone.y + zone.h / 2 + 4}
                        textAnchor="middle"
                        fill="#f8fafc"
                        fontSize={zone.w < 80 ? '10.5' : '13'}
                        fontWeight="600"
                      >
                        {zone.label}
                      </text>
                    </g>
                  );
                })}
              </svg>
            </div>

            <div className="lg:col-span-5 bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-5">
              <div className="space-y-1">
                <p className="text-xs text-amber-400 font-medium">Selected Callout</p>
                <h3 className="font-display text-2xl font-bold text-slate-100">{selectedCallout.label}</h3>
                <p className="text-xs font-mono text-slate-400 tabular-nums">{selectedCallout.coords}</p>
              </div>
              <p className="text-sm text-slate-300 leading-relaxed">{selectedCallout.detail}</p>

              <div className="border-t border-slate-800 pt-4 space-y-2.5 text-sm text-slate-300">
                <h4 className="font-display font-semibold text-slate-100 flex items-center gap-2">
                  <Shield className="w-4 h-4 text-sky-400" />
                  Mobile Optimization Rules Applied
                </h4>
                <p>Single-sample UV-tiled BoxMeshes and specular-free walls cut mobile GPU fragment load in half.</p>
                <p>0.60× internal 3D scale (~720p) + live COOL (540p / 45 FPS) preset prevent phone overheating.</p>
                <p>100% offline 5v5 AI uses hybrid NavMesh + multi-hop lane routing with radar gunfire pings.</p>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'files' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            <aside className="lg:col-span-4 bg-slate-900 border border-slate-800 rounded-xl p-3 max-h-[620px] overflow-y-auto">
              <div className="px-2 py-1.5 text-xs font-medium text-slate-400 flex items-center gap-2 border-b border-slate-800 mb-2">
                <FolderTree className="w-3.5 h-3.5" />
                godot_project ({allFiles.length} files)
              </div>
              <div className="space-y-0.5">
                {allFiles.map((f) => {
                  const active = selectedFile?.path === f.path;
                  return (
                    <button
                      key={f.path}
                      type="button"
                      onClick={() => setSelectedFilePath(f.path)}
                      className={`w-full text-left px-2.5 py-2 rounded-md text-xs font-mono truncate transition-colors cursor-pointer flex items-center gap-2 ${
                        active
                          ? 'bg-amber-400/15 text-amber-300'
                          : 'text-slate-300 hover:bg-slate-800/70'
                      }`}
                    >
                      <FileCode2 className="w-3.5 h-3.5 shrink-0 opacity-70" />
                      <span className="truncate">{f.path}</span>
                    </button>
                  );
                })}
              </div>
            </aside>

            <section className="lg:col-span-8 bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
              {selectedFile ? (
                <>
                  <div className="px-4 py-3 border-b border-slate-800 flex items-center justify-between gap-4">
                    <span className="font-mono text-xs text-slate-200 truncate">
                      godot_project/{selectedFile.path}
                    </span>
                    {selectedFile.kind === 'text' && selectedFile.content && (
                      <button
                        type="button"
                        onClick={() => handleCopy(selectedFile.path, selectedFile.content!)}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-md transition-colors cursor-pointer shrink-0"
                      >
                        {copiedPath === selectedFile.path ? (
                          <>
                            <Check className="w-3.5 h-3.5 text-emerald-400" />
                            Copied
                          </>
                        ) : (
                          <>
                            <Copy className="w-3.5 h-3.5" />
                            Copy
                          </>
                        )}
                      </button>
                    )}
                  </div>
                  {selectedFile.kind === 'png' && selectedFile.url ? (
                    <div className="p-8 flex flex-col items-center justify-center gap-4 bg-slate-950">
                      <img
                        src={selectedFile.url}
                        alt={selectedFile.path}
                        className="w-48 h-48 object-contain border border-slate-800 rounded-lg"
                        referrerPolicy="no-referrer"
                      />
                      <p className="text-xs font-mono text-slate-400">512 × 512 PBR PNG texture</p>
                    </div>
                  ) : (
                    <pre className="p-4 text-xs font-mono text-slate-200 overflow-x-auto max-h-[560px] leading-relaxed">
                      {selectedFile.content}
                    </pre>
                  )}
                </>
              ) : (
                <div className="p-8 text-sm text-slate-400">Select a file to inspect its contents.</div>
              )}
            </section>
          </div>
        )}
      </main>
    </div>
  );
}
