# ==============================================================================
# BLUE-TAURUS: FASE 11 - COMPLIANCE CIS v8 & NAVEGACAO (SANITIZED)
# Descrição: Implementa Menu Lateral, SPA Navigation e Modulo CIS v8.
# Fix 1.2: Sanitização total de caracteres HTML (Entidades) para evitar erros de encoding.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 11] Implementando Menu Lateral e Modulo CIS v8..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. UI: REESCREVER INDEX.HTML (Layout SPA + CIS)
# ==============================================================================
Write-Host "[UI] Atualizando assets/index.html com nova navegacao..." -ForegroundColor Green

$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | GRC Platform</title>
    
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/@phosphor-icons/web"></script>

    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                fontFamily: { sans: ['Inter', 'sans-serif'] },
                extend: {
                    colors: {
                        slate: { 850: '#151e2e', 900: '#0f172a' },
                        blue: { 450: '#4f85e4' }
                    }
                }
            }
        }
    </script>
    <style>
        body { background-color: #0b1120; color: #cbd5e1; }
        .card { background: #1e293b; border: 1px solid #334155; border-radius: 0.75rem; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
        .nav-item.active { background-color: rgba(59, 130, 246, 0.15); color: #60a5fa; border-right: 3px solid #60a5fa; }
        .cis-card { transition: all 0.2s; cursor: pointer; }
        .cis-card:hover { transform: translateY(-2px); border-color: #60a5fa; }
        
        /* Progress Bar Animation */
        @keyframes loadProgress { from { width: 0; } }
        .progress-bar { animation: loadProgress 1s ease-out forwards; }
        
        /* Modal Transitions */
        .modal { transition: opacity 0.25s ease; }
        body.modal-active { overflow: hidden; }
        
        ::-webkit-scrollbar { width: 8px; height: 8px; }
        ::-webkit-scrollbar-track { background: #0f172a; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 4px; }
    </style>
</head>
<body class="flex h-screen overflow-hidden">

    <!-- SIDEBAR DE NAVEGACAO -->
    <aside class="w-64 bg-slate-850 border-r border-slate-700 flex flex-col z-30">
        <!-- Logo -->
        <div class="h-16 flex items-center px-6 border-b border-slate-700/50">
            <i class="ph-fill ph-shield-check text-blue-500 text-2xl mr-2"></i>
            <h1 class="font-bold text-lg text-white tracking-tight">BLUE-TAURUS</h1>
        </div>

        <!-- Menu Links -->
        <nav class="flex-1 p-4 space-y-1 overflow-y-auto">
            <p class="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2 mt-2">Vis&atilde;o Geral</p>
            
            <a href="#" onclick="navigate('dashboard')" id="nav-dashboard" class="nav-item active flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 rounded-lg hover:text-white hover:bg-slate-800 transition-all">
                <i class="ph ph-chart-pie-slice text-lg"></i> Data Analytics
            </a>
            
            <a href="#" onclick="navigate('inventory')" id="nav-inventory" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 rounded-lg hover:text-white hover:bg-slate-800 transition-all">
                <i class="ph ph-desktop text-lg"></i> Invent&aacute;rio de Assets
            </a>

            <p class="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2 mt-6">Governan&ccedil;a</p>

            <a href="#" onclick="navigate('compliance')" id="nav-compliance" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 rounded-lg hover:text-white hover:bg-slate-800 transition-all">
                <i class="ph ph-check-circle text-lg"></i> Compliance CIS v8
            </a>
            
            <a href="#" onclick="Swal.fire('Em Breve', 'Gestao de Vulnerabilidades (CVEs)', 'info')" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 rounded-lg hover:text-white hover:bg-slate-800 transition-all">
                <i class="ph ph-warning-octagon text-lg"></i> Vulnerabilidades
            </a>

            <p class="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2 mt-6">Sistema</p>

            <a href="#" onclick="navigate('integrations')" id="nav-integrations" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 rounded-lg hover:text-white hover:bg-slate-800 transition-all">
                <i class="ph ph-plugs text-lg"></i> Integra&ccedil;&otilde;es API
            </a>
            
            <a href="#" onclick="navigate('config')" id="nav-config" class="nav-item flex items-center gap-3 px-3 py-2.5 text-sm font-medium text-slate-400 rounded-lg hover:text-white hover:bg-slate-800 transition-all">
                <i class="ph ph-gear text-lg"></i> Configura&ccedil;&otilde;es
            </a>
        </nav>

        <!-- User Profile Stub -->
        <div class="p-4 border-t border-slate-700/50">
            <div class="flex items-center gap-3">
                <div class="w-8 h-8 rounded-full bg-gradient-to-r from-blue-500 to-indigo-600 flex items-center justify-center text-xs font-bold text-white">AD</div>
                <div>
                    <p class="text-sm font-medium text-white">Admin</p>
                    <p class="text-xs text-slate-500">Security Officer</p>
                </div>
            </div>
        </div>
    </aside>

    <!-- AREA PRINCIPAL -->
    <main class="flex-1 flex flex-col overflow-hidden relative bg-[#0b1120]">
        
        <!-- Header Superior -->
        <header class="h-16 flex items-center justify-between px-8 border-b border-slate-700/50 bg-slate-900/50 backdrop-blur-sm">
            <h2 id="page-title" class="text-lg font-semibold text-white">Data Analytics Dashboard</h2>
            <div class="flex items-center gap-4">
                <span class="flex items-center gap-2 px-3 py-1 rounded-full bg-slate-800 border border-slate-700 text-xs text-slate-400">
                    <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> Sistema Online
                </span>
            </div>
        </header>

        <!-- CONTENT VIEWS (Telas que alternam) -->
        <div class="flex-1 overflow-y-auto p-8 scroll-smooth" id="content-area">
            
            <!-- VIEW: DASHBOARD (Analytics) -->
            <div id="view-dashboard" class="space-y-6 fade-in">
                <!-- KPIs -->
                <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
                    <div class="card p-6 border-l-4 border-blue-500"><p class="text-slate-400 text-xs uppercase font-bold">Total Ativos</p><h3 id="kpi-total" class="text-3xl font-bold text-white mt-2">--</h3></div>
                    <div class="card p-6 border-l-4 border-emerald-500"><p class="text-slate-400 text-xs uppercase font-bold">Compliance Score</p><h3 class="text-3xl font-bold text-emerald-400 mt-2">12%</h3><p class="text-xs text-slate-500 mt-1">Baseado no CIS v8</p></div>
                    <div class="card p-6 border-l-4 border-amber-500"><p class="text-slate-400 text-xs uppercase font-bold">Riscos Altos</p><h3 class="text-3xl font-bold text-white mt-2">3</h3></div>
                    <div class="card p-6 border-l-4 border-purple-500"><p class="text-slate-400 text-xs uppercase font-bold">Softwares</p><h3 id="kpi-soft" class="text-3xl font-bold text-white mt-2">--</h3></div>
                </div>
                <!-- Charts -->
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <div class="card p-6">
                        <h4 class="text-white font-semibold mb-4">Maturidade por Grupo (IG)</h4>
                        <div class="h-64"><canvas id="cisChart"></canvas></div>
                    </div>
                    <div class="card p-6">
                        <h4 class="text-white font-semibold mb-4">Sistemas Operacionais</h4>
                        <div class="h-64 flex justify-center"><canvas id="osChart"></canvas></div>
                    </div>
                </div>
            </div>

            <!-- VIEW: INVENTORY -->
            <div id="view-inventory" class="hidden space-y-6 fade-in">
                <div class="card overflow-hidden">
                    <div class="p-4 border-b border-slate-700 flex justify-between items-center bg-slate-800/50">
                        <div class="flex gap-2">
                            <input type="text" placeholder="Buscar host..." class="bg-slate-900 border border-slate-700 text-sm rounded-lg px-4 py-2 text-white focus:outline-none focus:border-blue-500">
                        </div>
                        <button onclick="fetchAgents()" class="text-slate-400 hover:text-white"><i class="ph-bold ph-arrows-clockwise text-xl"></i></button>
                    </div>
                    <table class="w-full text-left text-sm text-slate-300">
                        <thead class="bg-slate-800 text-xs uppercase text-slate-400"><tr><th class="p-4">Hostname</th><th class="p-4">OS</th><th class="p-4">IP</th><th class="p-4 text-right">A&ccedil;&atilde;o</th></tr></thead>
                        <tbody id="inventory-body" class="divide-y divide-slate-700"></tbody>
                    </table>
                </div>
            </div>

            <!-- VIEW: COMPLIANCE (CIS v8) -->
            <div id="view-compliance" class="hidden space-y-6 fade-in">
                <div class="flex justify-between items-end">
                    <div>
                        <h3 class="text-2xl font-bold text-white">CIS Critical Security Controls v8</h3>
                        <p class="text-slate-400 text-sm mt-1">Framework de prioriza&ccedil;&atilde;o para defesa cibern&eacute;tica.</p>
                    </div>
                    <div class="text-right">
                        <p class="text-xs text-slate-500 uppercase">Score Atual</p>
                        <p class="text-4xl font-bold text-blue-500">12<span class="text-lg text-slate-600">/100</span></p>
                    </div>
                </div>

                <!-- Grid de Controles -->
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4" id="cis-grid">
                    <!-- Cards gerados via JS -->
                </div>
            </div>

            <!-- VIEW: CONFIG & INTEGRATIONS (Placeholders) -->
            <div id="view-integrations" class="hidden fade-in">
                <div class="card p-8 text-center border-dashed border-2 border-slate-700 bg-transparent">
                    <i class="ph ph-plugs text-4xl text-slate-600 mb-4"></i>
                    <h3 class="text-xl font-bold text-white">Integra&ccedil;&otilde;es de API</h3>
                    <p class="text-slate-400 mt-2 mb-6">Conecte o Blue-Taurus a ferramentas externas (Slack, Jira, SIEMs).</p>
                    <button class="bg-blue-600 hover:bg-blue-500 text-white px-4 py-2 rounded-lg font-medium transition-colors">Nova Chave de API</button>
                </div>
            </div>
            
            <div id="view-config" class="hidden fade-in">
                <div class="card p-6 max-w-2xl">
                    <h3 class="text-lg font-bold text-white mb-4">Configura&ccedil;&otilde;es Gerais</h3>
                    <div class="space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-slate-400 mb-1">Nome da Organiza&ccedil;&atilde;o</label>
                            <input type="text" value="Minha Empresa S.A." class="w-full bg-slate-900 border border-slate-700 rounded-lg p-2.5 text-white">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-slate-400 mb-1">Intervalo de Heartbeat (segundos)</label>
                            <input type="number" value="30" class="w-full bg-slate-900 border border-slate-700 rounded-lg p-2.5 text-white">
                        </div>
                        <button class="bg-green-600 hover:bg-green-500 text-white px-4 py-2 rounded-lg text-sm font-medium">Salvar Altera&ccedil;&otilde;es</button>
                    </div>
                </div>
            </div>

        </div>
    </main>

    <!-- MODAL DETALHES -->
    <div id="details-modal" class="modal opacity-0 pointer-events-none fixed w-full h-full top-0 left-0 flex items-center justify-center z-50">
        <div class="modal-overlay absolute w-full h-full bg-black opacity-60 backdrop-blur-sm"></div>
        <div class="modal-container bg-slate-800 w-11/12 md:max-w-4xl mx-auto rounded-xl shadow-2xl z-50 overflow-hidden border border-slate-700 flex flex-col max-h-[90vh]">
            <div class="p-6 border-b border-slate-700 flex justify-between items-center bg-slate-900/50">
                <div>
                    <h3 class="text-xl font-bold text-white" id="modal-hostname">Host</h3>
                    <p class="text-xs text-slate-400 font-mono mt-1" id="modal-id">UUID</p>
                </div>
                <button onclick="closeModal()" class="text-slate-400 hover:text-white bg-slate-800 p-2 rounded-lg"><i class="ph-bold ph-x"></i></button>
            </div>
            <div class="p-6 overflow-y-auto">
                <!-- Hardware -->
                <div class="grid grid-cols-3 gap-4 mb-6">
                    <div class="bg-slate-700/30 p-4 rounded-lg border border-slate-600/50"><p class="text-xs text-slate-400 uppercase font-bold">CPU</p><p class="text-white text-sm mt-1" id="modal-cpu">-</p></div>
                    <div class="bg-slate-700/30 p-4 rounded-lg border border-slate-600/50"><p class="text-xs text-slate-400 uppercase font-bold">RAM</p><p class="text-white text-sm mt-1" id="modal-ram">-</p></div>
                    <div class="bg-slate-700/30 p-4 rounded-lg border border-slate-600/50"><p class="text-xs text-slate-400 uppercase font-bold">Disco</p><p class="text-white text-sm mt-1" id="modal-disk">-</p></div>
                </div>
                <!-- Tabs (Simuladas) -->
                <div class="flex gap-4 border-b border-slate-700 mb-4">
                    <button class="px-4 py-2 text-sm font-medium text-blue-400 border-b-2 border-blue-500">Software</button>
                    <button class="px-4 py-2 text-sm font-medium text-slate-400 hover:text-white">Perif&eacute;ricos</button>
                </div>
                <!-- Software List -->
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-xs">
                        <thead class="bg-slate-900 text-slate-400"><tr><th class="p-2">Nome</th><th class="p-2">Vers&atilde;o</th><th class="p-2">Vendor</th></tr></thead>
                        <tbody id="modal-sw-body" class="divide-y divide-slate-700 text-slate-300"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <script>
        // --- NAVEGACAO SPA ---
        function navigate(viewId) {
            // Esconde todas as views
            document.querySelectorAll('[id^="view-"]').forEach(el => el.classList.add('hidden'));
            // Remove active dos links
            document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
            
            // Mostra a view selecionada
            document.getElementById('view-' + viewId).classList.remove('hidden');
            document.getElementById('nav-' + viewId).classList.add('active');
            
            // Atualiza Titulo
            const titles = {
                'dashboard': 'Data Analytics Dashboard',
                'inventory': 'Invent&aacute;rio de Dispositivos',
                'compliance': 'Maturidade CIS Controls v8',
                'config': 'Configura&ccedil;&otilde;es do Sistema',
                'integrations': 'Integra&ccedil;&otilde;es e API'
            };
            document.getElementById('page-title').innerHTML = titles[viewId];
        }

        // --- DADOS DO CIS v8 (Mock Inicial) ---
        const cisControls = [
            { id: 1, name: "Invent&aacute;rio de Ativos", desc: "Gerenciar todos os dispositivos da rede.", score: 100, status: 'done' },
            { id: 2, name: "Invent&aacute;rio de Software", desc: "Gerenciar softwares autorizados.", score: 100, status: 'done' },
            { id: 3, name: "Prote&ccedil;&atilde;o de Dados", desc: "Identificar e criptografar dados sens&iacute;veis.", score: 0, status: 'todo' },
            { id: 4, name: "Configura&ccedil;&atilde;o Segura", desc: "Hardening de ativos e softwares.", score: 20, status: 'wip' },
            { id: 5, name: "Gest&atilde;o de Contas", desc: "Gerenciar credenciais e acessos.", score: 0, status: 'todo' },
            { id: 6, name: "Controle de Acesso", desc: "Gest&atilde;o de privil&eacute;gios administrativos.", score: 0, status: 'todo' },
            { id: 7, name: "Gest&atilde;o de Vulnerabilidades", desc: "Corre&ccedil;&atilde;o cont&iacute;nua de falhas.", score: 0, status: 'todo' },
            { id: 8, name: "Logs de Auditoria", desc: "Coleta e an&aacute;lise de eventos.", score: 100, status: 'done' }, 
            { id: 9, name: "Prote&ccedil;&atilde;o de Email/Web", desc: "Defesa contra amea&ccedil;as online.", score: 0, status: 'todo' },
            { id: 10, name: "Defesa contra Malware", desc: "Antiv&iacute;rus e EDR.", score: 0, status: 'todo' },
            { id: 11, name: "Recupera&ccedil;&atilde;o de Dados", desc: "Backups e Disaster Recovery.", score: 0, status: 'todo' },
            { id: 12, name: "Gest&atilde;o de Infra de Rede", desc: "Seguran&ccedil;a de Firewalls e Routers.", score: 0, status: 'todo' },
            { id: 13, name: "Defesa de Rede", desc: "Monitoramento de tr&aacute;fego e IDS.", score: 0, status: 'todo' },
            { id: 14, name: "Treinamento de Seguran&ccedil;a", desc: "Conscientiza&ccedil;&atilde;o de usu&aacute;rios.", score: 0, status: 'todo' },
            { id: 15, name: "Gest&atilde;o de Fornecedores", desc: "Seguran&ccedil;a na cadeia de suprimentos.", score: 0, status: 'todo' },
            { id: 16, name: "Seguran&ccedil;a de Aplica&ccedil;&atilde;o", desc: "SDLC seguro e testes.", score: 0, status: 'todo' },
            { id: 17, name: "Resposta a Incidentes", desc: "Planos e execu&ccedil;&atilde;o de resposta.", score: 20, status: 'wip' }, 
            { id: 18, name: "Testes de Invas&atilde;o", desc: "Pentests peri&oacute;dicos.", score: 0, status: 'todo' }
        ];

        function renderCIS() {
            const grid = document.getElementById('cis-grid');
            grid.innerHTML = '';
            
            cisControls.forEach(c => {
                let colorClass = 'border-slate-700';
                let icon = '<i class="ph ph-circle text-slate-500"></i>';
                let progressColor = 'bg-slate-600';
                
                if(c.status === 'done') { colorClass = 'border-emerald-500/50 bg-emerald-500/5'; icon = '<i class="ph-fill ph-check-circle text-emerald-500"></i>'; progressColor = 'bg-emerald-500'; }
                if(c.status === 'wip')  { colorClass = 'border-amber-500/50 bg-amber-500/5'; icon = '<i class="ph-fill ph-clock text-amber-500"></i>'; progressColor = 'bg-amber-500'; }

                grid.innerHTML += `
                    <div class="cis-card p-4 rounded-xl border ${colorClass} bg-slate-800/50 relative overflow-hidden group">
                        <div class="flex justify-between items-start mb-2">
                            <span class="text-xs font-bold text-slate-500 uppercase">Controle ${c.id.toString().padStart(2, '0')}</span>
                            ${icon}
                        </div>
                        <h4 class="font-bold text-white mb-1">${c.name}</h4>
                        <p class="text-xs text-slate-400 mb-4 h-8 overflow-hidden">${c.desc}</p>
                        
                        <div class="w-full bg-slate-700 h-1.5 rounded-full overflow-hidden">
                            <div class="${progressColor} h-full progress-bar" style="width: ${c.score}%"></div>
                        </div>
                        <div class="flex justify-between mt-2 text-[10px] text-slate-400 font-mono">
                            <span>Maturidade</span>
                            <span>${c.score}%</span>
                        </div>
                    </div>
                `;
            });
        }

        // --- API & INVENTORY LOGIC ---
        const API_URL = '/api/agents';
        
        async function fetchAgents() {
            try {
                const res = await fetch(API_URL);
                const agents = await res.json();
                
                // Deduplicate logic
                const map = new Map();
                agents.forEach(a => {
                    const exist = map.get(a.hostname);
                    const curr = new Date(a.last_seen_at || 0);
                    if(!exist || curr > new Date(exist.last_seen_at || 0)) map.set(a.hostname, a);
                });
                const unique = Array.from(map.values());

                // Update Tables & Stats
                renderInventory(unique);
                updateDashboard(unique);
            } catch(e) { console.error(e); }
        }

        function renderInventory(agents) {
            const tbody = document.getElementById('inventory-body');
            tbody.innerHTML = '';
            agents.forEach(a => {
                const badge = a.status === 'ONLINE' ? '<span class="text-emerald-400 text-xs font-bold">&#9679; ON</span>' : '<span class="text-slate-500 text-xs">&#9679; OFF</span>';
                tbody.innerHTML += `
                    <tr class="hover:bg-slate-800/50 border-b border-slate-700/50">
                        <td class="p-4 font-medium text-white">${a.hostname}</td>
                        <td class="p-4 text-slate-400">${a.os_name}</td>
                        <td class="p-4 font-mono text-xs">${a.ip_address || '-'}</td>
                        <td class="p-4 text-right"><button onclick="openDetails('${a.id}')" class="text-blue-400 hover:text-white text-xs font-bold border border-blue-500/30 px-3 py-1 rounded">Ver</button></td>
                    </tr>
                `;
            });
        }

        function updateDashboard(agents) {
            document.getElementById('kpi-total').innerText = agents.length;
            renderCharts(agents);
        }

        let osChartInstance = null;
        let cisChartInstance = null;

        function renderCharts(agents) {
            // OS Chart
            const osCounts = {};
            agents.forEach(a => { osCounts[a.os_name] = (osCounts[a.os_name] || 0) + 1 });
            const ctxOs = document.getElementById('osChart').getContext('2d');
            if(osChartInstance) osChartInstance.destroy();
            osChartInstance = new Chart(ctxOs, {
                type: 'doughnut',
                data: {
                    labels: Object.keys(osCounts),
                    datasets: [{ data: Object.values(osCounts), backgroundColor: ['#3b82f6', '#10b981', '#f59e0b'], borderColor: '#1e293b' }]
                },
                options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'right', labels: { color: '#94a3b8' } } } }
            });

            // CIS Progress Chart
            const ctxCis = document.getElementById('cisChart').getContext('2d');
            if(cisChartInstance) cisChartInstance.destroy();
            cisChartInstance = new Chart(ctxCis, {
                type: 'bar',
                data: {
                    labels: ['IG1 (B&aacute;sico)', 'IG2 (Essencial)', 'IG3 (Avan&ccedil;ado)'],
                    datasets: [{
                        label: 'Implementa&ccedil;&atilde;o %',
                        data: [85, 40, 10], 
                        backgroundColor: ['#10b981', '#f59e0b', '#ef4444'],
                        borderRadius: 4
                    }]
                },
                options: { 
                    responsive: true, 
                    maintainAspectRatio: false,
                    scales: { y: { beginAtZero: true, max: 100, grid: { color: '#334155' } }, x: { grid: { display: false } } },
                    plugins: { legend: { display: false } }
                }
            });
        }

        async function openDetails(id) {
            const modal = document.getElementById('details-modal');
            modal.classList.remove('opacity-0', 'pointer-events-none');
            document.getElementById('modal-hostname').innerText = "Carregando...";
            
            try {
                const res = await fetch('/api/agents/' + id + '/details');
                const data = await res.json();
                if(data) {
                    document.getElementById('modal-hostname').innerText = data.agent.hostname;
                    document.getElementById('modal-id').innerText = data.agent.id;
                    document.getElementById('modal-cpu').innerText = data.hardware?.cpu_model || '-';
                    document.getElementById('modal-ram').innerText = (data.hardware?.ram_total_mb/1024).toFixed(1) + ' GB';
                    document.getElementById('modal-disk').innerText = data.hardware?.disk_total_gb + ' GB';
                    
                    const swBody = document.getElementById('modal-sw-body');
                    swBody.innerHTML = '';
                    data.software.forEach(s => {
                        swBody.innerHTML += `<tr class="border-b border-slate-700/50"><td class="p-2 text-white">${s.name}</td><td class="p-2 text-slate-400">${s.version||'-'}</td><td class="p-2 text-slate-500">${s.vendor||'-'}</td></tr>`;
                    });
                }
            } catch(e) {}
        }
        function closeModal() { document.getElementById('details-modal').classList.add('opacity-0', 'pointer-events-none'); }

        renderCIS();
        fetchAgents();
        setInterval(fetchAgents, 5000);

    </script>
</body>
</html>
'@
$htmlContent | Out-File -FilePath "assets/index.html" -Encoding utf8

Write-Host "[SUCCESS] Nova Interface GRC com CIS v8 Instalada (SANITIZADA)!" -ForegroundColor Cyan
Write-Host "1. Apenas atualize a pagina no navegador (F5)."