# ==============================================================================
# BLUE-TAURUS: UI BRANDING UPDATE (SCI-FI THEME)
# Descrição: Aplica a nova identidade visual (Cores, Fontes, Nomes) ao index.html.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[UI] Aplicando identidade visual Cyber-Space..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/assets") { Set-Location $ProjectName }

# Conteúdo HTML com o novo Branding
$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | Command Bridge</title>
    
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    
    <!-- Fonte Tática: JetBrains Mono -->
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/@phosphor-icons/web"></script>

    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                fontFamily: { sans: ['"JetBrains Mono"', 'monospace'] },
                extend: {
                    colors: {
                        void: '#0b1120',      // Void Black
                        nebula: '#3b82f6',    // Nebula Blue
                        starlight: '#f8fafc', // Starlight White
                        alert: '#ef4444',     // Alert Red
                        success: '#10b981',   // Success Emerald
                        glass: 'rgba(30, 41, 59, 0.6)'
                    },
                    boxShadow: {
                        'neon': '0 0 10px rgba(59, 130, 246, 0.5)',
                        'neon-red': '0 0 10px rgba(239, 68, 68, 0.5)',
                    }
                }
            }
        }
    </script>
    <style>
        body { background-color: #0b1120; color: #f8fafc; background-image: radial-gradient(circle at 50% 0%, #1e293b 0%, #0b1120 60%); }
        
        /* Glassmorphism Cards */
        .card { 
            background: rgba(30, 41, 59, 0.4); 
            border: 1px solid rgba(59, 130, 246, 0.2); 
            backdrop-filter: blur(12px);
            border-radius: 0.5rem; 
            transition: all 0.3s ease;
        }
        .card:hover { border-color: rgba(59, 130, 246, 0.5); box-shadow: 0 0 15px rgba(59, 130, 246, 0.1); }

        /* Scrollbar Cyberpunk */
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: #020617; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: #3b82f6; }
        
        .nav-item.active { 
            background: linear-gradient(90deg, rgba(59,130,246,0.15) 0%, transparent 100%); 
            color: #60a5fa; 
            border-left: 2px solid #60a5fa; 
        }
        
        /* Animações */
        @keyframes scanline {
            0% { transform: translateY(-100%); }
            100% { transform: translateY(100%); }
        }
        .scan-overlay {
            position: fixed; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none;
            background: linear-gradient(to bottom, transparent 95%, rgba(59, 130, 246, 0.05) 98%, transparent 100%);
            animation: scanline 8s linear infinite;
            z-index: 9999;
        }
    </style>
</head>
<body class="flex h-screen overflow-hidden selection:bg-nebula selection:text-white">

    <!-- Scanline Effect (Opcional - Estética Sci-Fi) -->
    <div class="scan-overlay"></div>

    <!-- SIDEBAR -->
    <aside class="w-64 border-r border-slate-800 bg-slate-900/50 backdrop-blur-md flex flex-col z-30">
        <div class="h-20 flex items-center px-6 border-b border-slate-800">
            <i class="ph-fill ph-shield-star text-nebula text-3xl mr-3 animate-pulse"></i>
            <div>
                <h1 class="font-bold text-lg tracking-widest text-white">BLUE<span class="text-nebula">TAURUS</span></h1>
                <p class="text-[10px] text-slate-500 tracking-widest uppercase">Defense System v1.5</p>
            </div>
        </div>

        <nav class="flex-1 p-4 space-y-2 overflow-y-auto">
            <p class="px-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2 mt-4">Operations</p>
            
            <a href="#" onclick="navigate('dashboard')" id="nav-dashboard" class="nav-item active flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-squares-four text-lg"></i> Command Bridge
            </a>
            
            <a href="#" onclick="navigate('inventory')" id="nav-inventory" class="nav-item flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-hard-drives text-lg"></i> Sentinel Nodes
            </a>

            <p class="px-3 text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-2 mt-8">Defense Grid</p>

            <a href="#" onclick="navigate('compliance')" id="nav-compliance" class="nav-item flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-shield-check text-lg"></i> Shield Integrity
            </a>
            
            <a href="#" onclick="Swal.fire('Modulo Off-line', 'Radar de longo alcance inativo.', 'warning')" class="nav-item flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all">
                <i class="ph-bold ph-skull text-lg"></i> Hull Breaches
            </a>
             <a href="#" class="nav-item flex items-center gap-3 px-3 py-3 text-xs font-bold uppercase tracking-wider text-slate-400 hover:text-white transition-all opacity-50 cursor-not-allowed">
                <i class="ph-bold ph-radar text-lg"></i> Radar Deep-Space
            </a>
        </nav>

        <div class="p-4 border-t border-slate-800 bg-black/20">
            <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded border border-nebula bg-nebula/20 flex items-center justify-center text-xs font-bold text-nebula shadow-neon">CMDR</div>
                <div>
                    <p class="text-xs font-bold text-white uppercase">Commander</p>
                    <p class="text-[10px] text-emerald-500">SECURE LINK</p>
                </div>
            </div>
        </div>
    </aside>

    <!-- MAIN AREA -->
    <main class="flex-1 flex flex-col overflow-hidden relative">
        
        <header class="h-20 flex items-center justify-between px-8 border-b border-slate-800 bg-slate-900/30 backdrop-blur-md">
            <div>
                <h2 id="page-title" class="text-xl font-bold text-white tracking-wide">COMMAND BRIDGE</h2>
                <p class="text-[10px] text-slate-500 uppercase tracking-widest">Sector Alpha // Monitoring</p>
            </div>
            <div class="flex items-center gap-4">
                <div class="px-4 py-1.5 rounded border border-emerald-500/30 bg-emerald-500/10 text-emerald-400 text-xs font-bold uppercase tracking-wider flex items-center gap-2 shadow-neon">
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span> Systems Nominal
                </div>
            </div>
        </header>

        <div class="flex-1 overflow-y-auto p-8 scroll-smooth" id="content-area">
            
            <!-- VIEW: DASHBOARD -->
            <div id="view-dashboard" class="space-y-6 fade-in">
                <!-- KPIs -->
                <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                    <div class="card p-6 border-t-2 border-nebula">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Active Sentinels</p>
                        <h3 id="kpi-total" class="text-4xl font-bold text-white mt-2 font-mono">--</h3>
                    </div>
                    <div class="card p-6 border-t-2 border-emerald-500">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Shield Integrity</p>
                        <h3 id="kpi-score" class="text-4xl font-bold text-emerald-400 mt-2 font-mono">--%</h3>
                        <p class="text-[10px] text-slate-500 mt-1 uppercase">CIS Level 1</p>
                    </div>
                    <div class="card p-6 border-t-2 border-alert">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Critical Breaches</p>
                        <h3 class="text-4xl font-bold text-alert mt-2 font-mono">0</h3>
                    </div>
                    <div class="card p-6 border-t-2 border-purple-500">
                        <p class="text-slate-400 text-[10px] uppercase font-bold tracking-widest">Ops Rate (24h)</p>
                        <h3 class="text-4xl font-bold text-white mt-2 font-mono">--</h3>
                    </div>
                </div>

                <!-- Charts -->
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="card p-6">
                        <h4 class="text-white font-bold text-xs uppercase tracking-widest mb-6 border-b border-slate-700 pb-2">Compliance Vectors</h4>
                        <div class="h-64"><canvas id="cisChart"></canvas></div>
                    </div>
                    <div class="card p-6">
                        <h4 class="text-white font-bold text-xs uppercase tracking-widest mb-6 border-b border-slate-700 pb-2">OS Distribution</h4>
                        <div class="h-64 flex justify-center"><canvas id="osChart"></canvas></div>
                    </div>
                </div>
            </div>

            <!-- VIEW: INVENTORY -->
            <div id="view-inventory" class="hidden space-y-6 fade-in">
                <div class="card overflow-hidden">
                    <div class="p-4 border-b border-slate-700/50 flex justify-between items-center bg-black/20">
                        <h2 class="text-xs font-bold text-nebula uppercase tracking-widest flex items-center gap-2">
                            <i class="ph-bold ph-list-dashes text-lg"></i> Fleet Manifest
                        </h2>
                        <button onclick="fetchAgents()" class="text-slate-400 hover:text-white transition-transform hover:rotate-180"><i class="ph-bold ph-arrows-clockwise text-xl"></i></button>
                    </div>
                    <table class="w-full text-left text-xs font-mono">
                        <thead class="bg-slate-900/80 text-slate-500 font-bold uppercase tracking-wider">
                            <tr><th class="p-4">Node ID / Host</th><th class="p-4">Status</th><th class="p-4">OS Core</th><th class="p-4 text-center">Shield Score</th><th class="p-4">Last Signal</th><th class="p-4 text-right">Access</th></tr>
                        </thead>
                        <tbody id="inventory-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                    </table>
                </div>
            </div>

            <!-- VIEW: COMPLIANCE -->
            <div id="view-compliance" class="hidden space-y-6 fade-in">
                <div class="flex justify-between items-end border-b border-slate-800 pb-6">
                    <div>
                        <h3 class="text-2xl font-bold text-white tracking-tight">SHIELD INTEGRITY PROTOCOLS</h3>
                        <p class="text-slate-500 text-xs mt-1 font-mono uppercase">Standard: CIS Critical Security Controls v8.1</p>
                    </div>
                    <div class="text-right">
                        <p class="text-[10px] text-slate-500 uppercase tracking-widest">Global Integrity</p>
                        <p class="text-5xl font-bold text-nebula font-mono">--%</p>
                    </div>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4" id="cis-grid"></div>
            </div>

        </div>
    </main>

    <!-- MODAL DETALHES -->
    <div id="details-modal" class="modal opacity-0 pointer-events-none fixed w-full h-full top-0 left-0 flex items-center justify-center z-50">
        <div class="modal-overlay absolute w-full h-full bg-black/80 backdrop-blur-sm"></div>
        <div class="modal-container bg-[#0f172a] w-11/12 md:max-w-5xl mx-auto border border-nebula/30 shadow-[0_0_50px_rgba(59,130,246,0.15)] flex flex-col max-h-[90vh]">
            <!-- Modal Header -->
            <div class="p-6 border-b border-slate-800 flex justify-between items-center bg-black/40">
                <div class="flex items-center gap-4">
                    <div class="w-10 h-10 rounded border border-slate-700 bg-slate-800 flex items-center justify-center text-nebula"><i class="ph-fill ph-desktop text-2xl"></i></div>
                    <div>
                        <h3 class="text-xl font-bold text-white tracking-wide" id="modal-hostname">HOST</h3>
                        <p class="text-[10px] text-slate-500 font-mono mt-0.5 uppercase tracking-wider" id="modal-id">UUID</p>
                    </div>
                </div>
                <button onclick="closeModal()" class="text-slate-400 hover:text-alert transition-colors"><i class="ph-bold ph-x text-2xl"></i></button>
            </div>
            
            <div class="flex-1 flex overflow-hidden">
                <!-- Modal Sidebar -->
                <div class="w-48 bg-black/20 border-r border-slate-800 p-4 space-y-2">
                    <button id="tab-hw" onclick="switchTab('hw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">HARDWARE</button>
                    <button id="tab-sw" onclick="switchTab('sw')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SOFTWARE</button>
                    <button id="tab-cis" onclick="switchTab('cis')" class="tab-btn w-full text-left px-4 py-3 rounded text-xs font-bold uppercase tracking-wider text-slate-400 hover:bg-slate-800 hover:text-white transition-all border-l-2 border-transparent">SECURITY</button>
                </div>

                <!-- Modal Content -->
                <div class="flex-1 p-8 overflow-y-auto bg-slate-900/50">
                    <!-- HW TAB -->
                    <div id="content-hw" class="space-y-6">
                        <div class="grid grid-cols-4 gap-4">
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">CPU Core</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-cpu">-</p></div>
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Threads</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-cores">-</p></div>
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Memory</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-ram">-</p></div>
                            <div class="card p-4 text-center"><p class="text-[10px] text-slate-500 uppercase">Storage</p><p class="text-white font-bold font-mono text-sm mt-1" id="modal-disk">-</p></div>
                        </div>
                        
                        <!-- Thermal -->
                        <div class="card p-4 border-l-4 border-l-orange-500 bg-orange-500/5" id="thermal-card">
                             <div class="flex justify-between items-center">
                                <span class="text-xs font-bold text-orange-400 uppercase tracking-widest">Thermal Sensor</span>
                                <span class="text-xl font-bold text-white font-mono" id="modal-temp">--</span>
                             </div>
                        </div>
                    </div>

                    <!-- SW TAB -->
                    <div id="content-sw" class="hidden">
                        <table class="w-full text-left text-xs font-mono">
                            <thead class="text-slate-500 border-b border-slate-700"><tr><th class="pb-2">PACKAGE</th><th class="pb-2">VERSION</th><th class="pb-2">VENDOR</th></tr></thead>
                            <tbody id="modal-sw-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                        </table>
                    </div>

                    <!-- CIS TAB -->
                    <div id="content-cis" class="hidden">
                        <div class="mb-6 flex justify-between items-center pb-4 border-b border-slate-800">
                            <div><span class="text-xs text-slate-500 uppercase">Audit Status</span><div class="text-lg font-bold text-white mt-1" id="modal-score-explain">--</div></div>
                            <div class="px-3 py-1 rounded bg-blue-500/10 text-blue-400 text-xs font-mono border border-blue-500/20" id="modal-policy-name">--</div>
                        </div>
                        <table class="w-full text-left text-xs font-mono">
                            <thead class="text-slate-500"><tr><th class="pb-2 w-16">RESULT</th><th class="pb-2">RULE</th><th class="pb-2">OUTPUT</th></tr></thead>
                            <tbody id="modal-cis-body" class="divide-y divide-slate-800 text-slate-300"></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- JS LOGIC (Mantida e Adaptada) -->
    <script>
        const API_URL = '/api/agents';
        let uniqueAgents = [];

        async function fetchAgents() {
            try {
                const res = await fetch(API_URL);
                const agents = await res.json();
                const map = new Map();
                agents.forEach(a => {
                    const exist = map.get(a.hostname);
                    const curr = new Date(a.last_seen_at || 0);
                    if(!exist || curr > new Date(exist.last_seen_at || 0)) map.set(a.hostname, a);
                });
                uniqueAgents = Array.from(map.values());
                renderTable();
                renderKPIs();
            } catch(e) { console.error(e); }
        }

        function renderKPIs() {
            document.getElementById('kpi-total').innerText = uniqueAgents.length;
            let totalScore = 0, scoredAgents = 0;
            uniqueAgents.forEach(a => { if (a.compliance_score != null) { totalScore += a.compliance_score; scoredAgents++; } });
            const avg = scoredAgents > 0 ? Math.round(totalScore / scoredAgents) : 0;
            document.getElementById('kpi-score').innerText = avg + '%';
        }

        function renderTable() {
            const tbody = document.getElementById('inventory-body');
            tbody.innerHTML = '';
            uniqueAgents.forEach(a => {
                const status = a.status === 'ONLINE' 
                    ? '<span class="text-emerald-400 font-bold drop-shadow-[0_0_5px_rgba(16,185,129,0.5)]">● ON</span>' 
                    : '<span class="text-slate-600 font-bold">● OFF</span>';
                
                let score = '<span class="text-slate-700">-</span>';
                if(a.compliance_score !== null) {
                    let c = 'text-alert border-alert/30 bg-alert/10';
                    if(a.compliance_score >= 80) c = 'text-emerald-400 border-emerald-500/30 bg-emerald-500/10';
                    else if(a.compliance_score >= 50) c = 'text-amber-400 border-amber-500/30 bg-amber-500/10';
                    score = `<span class="px-2 py-0.5 rounded border ${c} font-bold text-[10px]">${a.compliance_score}%</span>`;
                }

                tbody.innerHTML += `
                    <tr class="hover:bg-white/5 transition-colors border-b border-slate-800/50">
                        <td class="p-4 font-bold text-white">${a.hostname}<div class="text-[10px] text-slate-600 font-normal">${a.id.substring(0,8)}</div></td>
                        <td class="p-4 text-xs">${status}</td>
                        <td class="p-4 text-slate-400">${a.os_name}</td>
                        <td class="p-4 text-center">${score}</td>
                        <td class="p-4 text-slate-500 text-[10px]">${new Date(a.last_seen_at).toLocaleTimeString()}</td>
                        <td class="p-4 text-right"><button onclick="openDetails('${a.id}')" class="text-nebula hover:text-white text-xs font-bold border border-nebula/30 hover:bg-nebula hover:border-nebula px-3 py-1 rounded transition-all shadow-neon">ACCESS</button></td>
                    </tr>`;
            });
        }

        // Mock CIS Controls for Chart
        const cisControls = [
            { id: 1, name: "Asset Inv", score: 100 }, { id: 2, name: "Soft Inv", score: 100 },
            { id: 3, name: "Data Prot", score: 33 }, { id: 4, name: "Secure Config", score: 50 },
            { id: 8, name: "Logs", score: 100 }
        ];

        function renderCIS() {
            const grid = document.getElementById('cis-grid');
            grid.innerHTML = '';
            cisControls.forEach(c => {
               let color = c.score == 100 ? 'border-emerald-500/30 bg-emerald-500/5' : 'border-slate-700 bg-slate-800/50';
               let text = c.score == 100 ? 'text-emerald-400' : 'text-slate-400';
               grid.innerHTML += `
                <div class="card p-4 ${color} border flex justify-between items-center">
                    <div><p class="text-[10px] text-slate-500 uppercase font-bold">Control 0${c.id}</p><h4 class="text-sm font-bold text-white">${c.name}</h4></div>
                    <div class="text-xl font-mono font-bold ${text}">${c.score}%</div>
                </div>`; 
            });
        }

        // Navigation
        function navigate(view) {
            document.querySelectorAll('[id^="view-"]').forEach(e => e.classList.add('hidden'));
            document.getElementById('view-' + view).classList.remove('hidden');
            document.querySelectorAll('.nav-item').forEach(e => e.classList.remove('active', 'text-nebula'));
            document.getElementById('nav-' + view).classList.add('active', 'text-nebula');
            
            const titles = {'dashboard': 'COMMAND BRIDGE', 'inventory': 'SENTINEL NODES', 'compliance': 'SHIELD INTEGRITY'};
            document.getElementById('page-title').innerText = titles[view];
        }

        // Modal Logic (Igual ao anterior, apenas IDs ajustados)
        async function openDetails(id) {
            document.getElementById('details-modal').classList.remove('opacity-0', 'pointer-events-none');
            // (Logica de fetch mantida igual, apenas renderizando nos novos IDs)
            try {
                const res = await fetch('/api/agents/' + id + '/details');
                const data = await res.json();
                if(data) {
                    document.getElementById('modal-hostname').innerText = data.agent.hostname;
                    document.getElementById('modal-id').innerText = data.agent.id;
                    const hw = data.hardware || {};
                    document.getElementById('modal-cpu').innerText = hw.cpu_model || 'Unknown';
                    document.getElementById('modal-cores').innerText = hw.cpu_cores || '-';
                    document.getElementById('modal-ram').innerText = (hw.ram_total_mb/1024).toFixed(1) + ' GB';
                    document.getElementById('modal-disk').innerText = hw.disk_total_gb + ' GB';
                    
                    // Temp
                    if(hw.cpu_temp_c) {
                        document.getElementById('modal-temp').innerHTML = `${Math.round(hw.cpu_temp_c)}&deg;C`;
                        if(hw.cpu_temp_c > 75) document.getElementById('thermal-card').classList.add('animate-pulse');
                    } else { document.getElementById('modal-temp').innerText = "N/A"; }

                    // Software
                    const swBody = document.getElementById('modal-sw-body'); swBody.innerHTML = '';
                    data.software.forEach(s => swBody.innerHTML += `<tr class="border-b border-slate-800/50"><td class="py-2 text-white">${s.name}</td><td class="py-2 text-slate-500">${s.version||'-'}</td><td class="py-2 text-slate-600">${s.vendor||'-'}</td></tr>`);

                    // CIS
                    const cisBody = document.getElementById('modal-cis-body'); cisBody.innerHTML = '';
                    if(data.compliance && data.compliance.details) {
                        data.compliance.details.forEach(r => {
                            const badge = r.status === 'PASS' ? '<span class="text-emerald-400 font-bold">PASS</span>' : '<span class="text-alert font-bold">FAIL</span>';
                            cisBody.innerHTML += `<tr class="border-b border-slate-800/50"><td class="py-2 text-xs">${badge}</td><td class="py-2 text-white">${r.title}</td><td class="py-2 text-slate-500 font-mono text-[10px]">${r.output}</td></tr>`;
                        });
                        document.getElementById('modal-score-explain').innerText = data.compliance.score + '% Secure';
                    }
                }
            } catch(e){}
        }

        function switchTab(t) {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('text-nebula', 'border-nebula'));
            document.getElementById('tab-'+t).classList.add('text-nebula', 'border-nebula');
            document.querySelectorAll('[id^="content-"]').forEach(c => c.classList.add('hidden'));
            document.getElementById('content-'+t).classList.remove('hidden');
        }

        function closeModal() { document.getElementById('details-modal').classList.add('opacity-0', 'pointer-events-none'); }
        
        renderCIS();
        fetchAgents();
        setInterval(fetchAgents, 5000);
    </script>
</body>
</html>
'@
$Utf8NoBom = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText("$PWD/assets/index.html", $htmlContent, $Utf8NoBom)

Write-Host "[SUCCESS] Identidade Visual Aplicada! (Reinicie o servidor se necessario)" -ForegroundColor Cyan