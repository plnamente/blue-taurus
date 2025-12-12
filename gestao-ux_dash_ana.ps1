# ==============================================================================
# BLUE-TAURUS: FASE 9 - DATA SCIENCE DASHBOARD UI
# Descrição: Interface avançada com gráficos (Chart.js), KPIs e deduplicação visual.
# Fix 1.1: Correção de caracteres acentuados (Encoding) usando HTML Entities.
# ==============================================================================

$ProjectName = "blue-taurus"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "[PHASE 9] Construindo Dashboard Data Science..." -ForegroundColor Cyan

if (Test-Path "$ProjectName/crates/server") { Set-Location $ProjectName }

# ==============================================================================
# 1. ATUALIZAR FRONTEND (HTML + CHART.JS)
# ==============================================================================
Write-Host "[UI] Reescrevendo assets/index.html com novo layout..." -ForegroundColor Green

$htmlContent = @'
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blue-Taurus | Security Insights</title>
    
    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    
    <!-- Chart.js (Graficos) -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    
    <!-- SweetAlert2 -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>

    <!-- Fontes e Icones -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <!-- Phosphor Icons (Mais modernos) -->
    <script src="https://unpkg.com/@phosphor-icons/web"></script>

    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                fontFamily: { sans: ['Inter', 'sans-serif'] },
                extend: {
                    colors: {
                        slate: { 850: '#151e2e', 900: '#0f172a' },
                        blue: { 450: '#4f85e4' } // Tom mais suave Data Science
                    }
                }
            }
        }
    </script>
    <style>
        body { background-color: #0b1120; color: #cbd5e1; }
        .card { background: #1e293b; border: 1px solid #334155; border-radius: 0.75rem; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
        .gradient-text { background: linear-gradient(to right, #60a5fa, #a78bfa); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        
        /* Scrollbar custom */
        ::-webkit-scrollbar { width: 8px; height: 8px; }
        ::-webkit-scrollbar-track { background: #0f172a; }
        ::-webkit-scrollbar-thumb { background: #334155; border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: #475569; }
    </style>
</head>
<body class="flex flex-col h-screen overflow-hidden">

    <!-- Navbar Superior -->
    <header class="h-16 border-b border-slate-700 bg-slate-900/80 backdrop-blur-md flex items-center justify-between px-6 z-20">
        <div class="flex items-center gap-3">
            <i class="ph-fill ph-shield-check text-blue-500 text-3xl"></i>
            <div>
                <h1 class="font-bold text-xl tracking-tight text-white">BLUE-TAURUS <span class="text-[10px] text-blue-400 border border-blue-500/30 px-1 rounded uppercase">Enterprise</span></h1>
            </div>
        </div>
        
        <div class="flex items-center gap-6">
            <div class="hidden md:flex items-center gap-2 text-sm text-slate-400">
                <span class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
                <span>System Operational</span>
            </div>
            <div class="h-8 w-8 rounded-full bg-gradient-to-tr from-blue-500 to-purple-500 flex items-center justify-center text-white font-bold text-xs shadow-lg shadow-blue-500/20">
                AD
            </div>
        </div>
    </header>

    <!-- Layout Principal -->
    <div class="flex flex-1 overflow-hidden">
        
        <!-- Sidebar (Navegação) -->
        <aside class="w-64 bg-slate-850 border-r border-slate-700 hidden md:flex flex-col justify-between p-4">
            <nav class="space-y-1">
                <a href="#" class="flex items-center gap-3 px-3 py-2 text-white bg-blue-600/20 text-blue-400 rounded-lg font-medium border border-blue-500/10">
                    <i class="ph ph-squares-four text-lg"></i> Dashboard
                </a>
                <a href="#" onclick="Swal.fire('Em breve', 'Modulo de Ameaças em desenvolvimento', 'info')" class="flex items-center gap-3 px-3 py-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors">
                    <i class="ph ph-bug text-lg"></i> Amea&ccedil;as <span class="ml-auto bg-red-500/20 text-red-400 text-[10px] px-1.5 rounded">0</span>
                </a>
                <a href="#" onclick="Swal.fire('Em breve', 'Relatorios PDF', 'info')" class="flex items-center gap-3 px-3 py-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors">
                    <i class="ph ph-file-text text-lg"></i> Relat&oacute;rios
                </a>
                <a href="#" class="flex items-center gap-3 px-3 py-2 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors">
                    <i class="ph ph-gear text-lg"></i> Configura&ccedil;&otilde;es
                </a>
            </nav>
            
            <div class="p-4 bg-slate-800/50 rounded-xl border border-slate-700/50">
                <p class="text-xs text-slate-400 mb-2">Armazenamento</p>
                <div class="w-full bg-slate-700 h-1.5 rounded-full overflow-hidden mb-1">
                    <div class="bg-blue-500 h-full w-[15%]"></div>
                </div>
                <p class="text-[10px] text-slate-500">1.2GB / 100GB Usados</p>
            </div>
        </aside>

        <!-- Area de Conteudo (Scrollavel) -->
        <main class="flex-1 overflow-y-auto p-6 bg-[#0b1120]">
            
            <!-- KPIs Header -->
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
                <!-- Card 1 -->
                <div class="card p-5 border-l-4 border-l-blue-500 relative overflow-hidden group">
                    <div class="absolute right-0 top-0 opacity-10 transform translate-x-2 -translate-y-2 group-hover:scale-110 transition-transform">
                        <i class="ph-fill ph-desktop text-8xl text-blue-500"></i>
                    </div>
                    <p class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Total Ativos</p>
                    <h3 id="kpi-total" class="text-3xl font-bold text-white mt-1">--</h3>
                    <p class="text-xs text-green-400 mt-2 flex items-center gap-1">
                        <i class="ph-bold ph-trend-up"></i> +100% este m&ecirc;s
                    </p>
                </div>

                <!-- Card 2 -->
                <div class="card p-5 border-l-4 border-l-emerald-500">
                    <p class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Online Agora</p>
                    <h3 id="kpi-online" class="text-3xl font-bold text-white mt-1">--</h3>
                    <p class="text-xs text-emerald-400 mt-2">Conectividade Est&aacute;vel</p>
                </div>

                <!-- Card 3 (Mockado para dar ideia de futuro) -->
                <div class="card p-5 border-l-4 border-l-red-500">
                    <p class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Amea&ccedil;as Detectadas</p>
                    <h3 class="text-3xl font-bold text-white mt-1">0</h3>
                    <p class="text-xs text-slate-500 mt-2">Nenhum incidente cr&iacute;tico</p>
                </div>

                <!-- Card 4 (Mockado) -->
                <div class="card p-5 border-l-4 border-l-amber-500">
                    <p class="text-slate-400 text-xs font-semibold uppercase tracking-wider">Vulnerabilidades</p>
                    <h3 class="text-3xl font-bold text-white mt-1">12</h3>
                    <p class="text-xs text-amber-400 mt-2">Requer aten&ccedil;&atilde;o (Patching)</p>
                </div>
            </div>

            <!-- Charts Row -->
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
                <!-- Grafico de Pizza (OS Distribution) -->
                <div class="card p-5 lg:col-span-1">
                    <h3 class="text-sm font-semibold text-white mb-4">Sistemas Operacionais</h3>
                    <div class="relative h-48 w-full flex justify-center">
                        <canvas id="osChart"></canvas>
                    </div>
                </div>

                <!-- Grafico de Barras (Atividade Recente - Mockado/Simulado) -->
                <div class="card p-5 lg:col-span-2">
                    <h3 class="text-sm font-semibold text-white mb-4">Volume de Eventos (24h)</h3>
                    <div class="relative h-48 w-full">
                        <canvas id="eventsChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- Tabela Principal -->
            <div class="card overflow-hidden">
                <div class="p-4 border-b border-slate-700 flex justify-between items-center bg-slate-800/50">
                    <h2 class="text-sm font-bold text-white flex items-center gap-2">
                        <i class="ph-duotone ph-list-dashes text-lg text-blue-400"></i>
                        Invent&aacute;rio de M&aacute;quinas
                    </h2>
                    
                    <div class="flex gap-2">
                        <button id="btn-delete" onclick="confirmDelete()" class="hidden bg-red-500/10 text-red-400 hover:bg-red-500 hover:text-white px-3 py-1.5 rounded text-xs font-medium border border-red-500/20 transition-all flex items-center gap-2">
                            <i class="ph-bold ph-trash"></i> Excluir Sele&ccedil;&atilde;o
                        </button>
                        <button onclick="fetchAgents()" class="bg-slate-700 hover:bg-slate-600 text-white px-3 py-1.5 rounded text-xs font-medium transition-all">
                            <i class="ph-bold ph-arrows-clockwise"></i>
                        </button>
                    </div>
                </div>
                
                <div class="overflow-x-auto">
                    <table class="w-full text-left text-xs">
                        <thead class="bg-slate-800/80 text-slate-400 font-semibold uppercase tracking-wider">
                            <tr>
                                <th class="p-3 w-8 text-center"><input type="checkbox" id="select-all" onclick="toggleSelectAll()" class="rounded bg-slate-700 border-slate-600"></th>
                                <th class="p-3">Ativo / Hostname</th>
                                <th class="p-3">Status</th>
                                <th class="p-3">Sistema</th>
                                <th class="p-3">IP Address</th>
                                <th class="p-3">&Uacute;ltimo Visto</th>
                                <th class="p-3 text-right">A&ccedil;&atilde;o</th>
                            </tr>
                        </thead>
                        <tbody id="table-body" class="divide-y divide-slate-700/50 text-slate-300">
                            <!-- JS Injection -->
                        </tbody>
                    </table>
                </div>
                <div class="p-3 bg-slate-800/30 text-[10px] text-slate-500 text-center border-t border-slate-700">
                    Mostrando <span id="showing-count">0</span> ativos &uacute;nicos (Deduplicados automaticamente)
                </div>
            </div>

        </main>
    </div>

    <!-- SCRIPT LOGIC -->
    <script>
        const API_URL = '/api/agents';
        let rawAgents = [];
        let uniqueAgents = [];
        let selectedIds = new Set();
        let osChartInstance = null;
        let eventsChartInstance = null;

        // --- CORE: FETCH & DEDUPLICATE ---
        async function fetchAgents() {
            try {
                const res = await fetch(API_URL);
                rawAgents = await res.json();
                
                // LOGICA DE DEDUPLICACAO (Group by Hostname, keep latest)
                const map = new Map();
                rawAgents.forEach(agent => {
                    // Se nao existe ou se este agent eh mais recente que o guardado, substitui
                    const existing = map.get(agent.hostname);
                    const currentDate = new Date(agent.last_seen_at || 0);
                    const existingDate = existing ? new Date(existing.last_seen_at || 0) : new Date(0);
                    
                    if (!existing || currentDate > existingDate) {
                        map.set(agent.hostname, agent);
                    }
                });
                
                uniqueAgents = Array.from(map.values());
                
                updateUI();
            } catch (e) {
                console.error("Erro API:", e);
            }
        }

        function updateUI() {
            renderKPIs();
            renderTable();
            renderCharts();
        }

        // --- RENDERERS ---
        function renderKPIs() {
            document.getElementById('kpi-total').innerText = uniqueAgents.length;
            const onlineCount = uniqueAgents.filter(a => a.status === 'ONLINE').length;
            document.getElementById('kpi-online').innerText = onlineCount;
            document.getElementById('showing-count').innerText = uniqueAgents.length;
        }

        function renderTable() {
            const tbody = document.getElementById('table-body');
            tbody.innerHTML = '';

            uniqueAgents.forEach(agent => {
                const isSelected = selectedIds.has(agent.id);
                const lastSeen = agent.last_seen_at ? new Date(agent.last_seen_at).toLocaleString() : 'N/A';
                
                // Status Badge Logic
                let statusBadge = '';
                if(agent.status === 'ONLINE') {
                    statusBadge = '<span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"><span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span> ONLINE</span>';
                } else {
                    statusBadge = '<span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-medium bg-slate-700 text-slate-400 border border-slate-600">OFFLINE</span>';
                }

                // Icon OS
                const iconClass = agent.os_name.toLowerCase().includes('windows') ? 'ph-windows-logo' : 'ph-linux-logo';

                const row = document.createElement('tr');
                row.className = isSelected ? 'bg-blue-500/10' : 'hover:bg-slate-800/50 transition-colors';
                row.innerHTML = `
                    <td class="p-3 text-center"><input type="checkbox" onclick="toggleSelect('${agent.id}')" ${isSelected ? 'checked' : ''} class="rounded bg-slate-700 border-slate-600 text-blue-500 focus:ring-0"></td>
                    <td class="p-3 font-medium text-white flex items-center gap-2">
                        <div class="w-8 h-8 rounded bg-slate-700 flex items-center justify-center text-slate-300">
                            <i class="ph-fill ${iconClass} text-lg"></i>
                        </div>
                        <div>
                            <div>${agent.hostname}</div>
                            <div class="text-[10px] text-slate-500 font-mono">${agent.id.substring(0,8)}...</div>
                        </div>
                    </td>
                    <td class="p-3">${statusBadge}</td>
                    <td class="p-3 text-slate-400">${agent.os_name} <span class="text-xs text-slate-600">${agent.kernel_version || ''}</span></td>
                    <td class="p-3 font-mono text-slate-400">${agent.ip_address || '--'}</td>
                    <td class="p-3 text-slate-500">${lastSeen}</td>
                    <td class="p-3 text-right">
                        <button class="text-slate-400 hover:text-blue-400 transition-colors"><i class="ph-bold ph-caret-right"></i></button>
                    </td>
                `;
                tbody.appendChild(row);
            });
            
            // Show/Hide Delete Button
            const btn = document.getElementById('btn-delete');
            if(selectedIds.size > 0) btn.classList.remove('hidden');
            else btn.classList.add('hidden');
        }

        function renderCharts() {
            // 1. OS Distribution
            const osCounts = {};
            uniqueAgents.forEach(a => { osCounts[a.os_name] = (osCounts[a.os_name] || 0) + 1 });
            
            const ctxOs = document.getElementById('osChart').getContext('2d');
            if (osChartInstance) osChartInstance.destroy();
            
            osChartInstance = new Chart(ctxOs, {
                type: 'doughnut',
                data: {
                    labels: Object.keys(osCounts),
                    datasets: [{
                        data: Object.values(osCounts),
                        backgroundColor: ['#3b82f6', '#10b981', '#f59e0b'],
                        borderColor: '#1e293b',
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { position: 'right', labels: { color: '#94a3b8', font: { size: 10 } } } }
                }
            });

            // 2. Events (Mockado para demo visual)
            if (!eventsChartInstance) {
                const ctxEvt = document.getElementById('eventsChart').getContext('2d');
                eventsChartInstance = new Chart(ctxEvt, {
                    type: 'bar',
                    data: {
                        labels: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'],
                        datasets: [{
                            label: 'Handshakes',
                            data: [12, 19, 3, 5, 2, 3],
                            backgroundColor: '#3b82f6',
                            borderRadius: 4
                        }, {
                            label: 'Erros',
                            data: [1, 2, 0, 0, 1, 0],
                            backgroundColor: '#ef4444',
                            borderRadius: 4
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: { legend: { display: false } },
                        scales: {
                            y: { grid: { color: '#334155' }, ticks: { color: '#64748b' } },
                            x: { grid: { display: false }, ticks: { color: '#64748b' } }
                        }
                    }
                });
            }
        }

        // --- ACTIONS ---
        function toggleSelect(id) {
            if(selectedIds.has(id)) selectedIds.delete(id);
            else selectedIds.add(id);
            renderTable();
        }

        function toggleSelectAll() {
            const check = document.getElementById('select-all').checked;
            if(check) uniqueAgents.forEach(a => selectedIds.add(a.id));
            else selectedIds.clear();
            renderTable();
        }

        async function confirmDelete() {
            const result = await Swal.fire({
                title: 'Excluir Ativos?',
                text: "Essa ação removerá o histórico do banco de dados.",
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#ef4444',
                background: '#1e293b',
                color: '#fff'
            });

            if (result.isConfirmed) {
                for (let id of selectedIds) {
                    await fetch(`${API_URL}/${id}`, { method: 'DELETE' });
                }
                selectedIds.clear();
                fetchAgents();
                Swal.fire({ title: 'Limpo!', icon: 'success', timer: 1500, showConfirmButton: false, background: '#1e293b', color: '#fff' });
            }
        }

        // Init
        fetchAgents();
        setInterval(fetchAgents, 5000); // Polling 5s
    </script>
</body>
</html>
'@
$htmlContent | Out-File -FilePath "assets/index.html" -Encoding utf8

Write-Host "[SUCCESS] Dashboard Data Science instalado!" -ForegroundColor Cyan