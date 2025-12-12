use sysinfo::{CpuExt, DiskExt, System, SystemExt, UserExt};
use shared::models::{HostInfo, HardwareInfo, SoftwareInfo};
use std::process::Command;

pub struct SystemCollector {
    sys: System,
}

impl SystemCollector {
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        Self { sys }
    }

    fn get_peripherals(&self) -> Vec<String> {
        let mut devices = Vec::new();
        if cfg!(target_os = "windows") {
            // Usa PowerShell para listar USBs
            let output = Command::new("powershell")
                .args(&["-Command", "Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like '*USB*' } | Select-Object -ExpandProperty FriendlyName"])
                .output();
            if let Ok(o) = output {
                for line in String::from_utf8_lossy(&o.stdout).lines() {
                    let t = line.trim(); 
                    if !t.is_empty() { devices.push(t.to_string()); }
                }
            }
        } else {
            devices.push("Generic Linux Device".to_string());
        }
        devices
    }

    fn get_software(&self) -> Vec<SoftwareInfo> {
        let mut software_list = Vec::new();

        if cfg!(target_os = "windows") {
            // Script PowerShell robusto para ler Uninstall Keys do Registro (32 e 64 bits)
            let ps_script = r#"
            $keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            Get-ItemProperty $keys -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -ne $null } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | 
            ConvertTo-Json -Compress
            "#;

            let output = Command::new("powershell")
                .args(&["-Command", ps_script])
                .output();

            if let Ok(o) = output {
                let json_str = String::from_utf8_lossy(&o.stdout);
                
                // Estrutura temporaria para desserializar o JSON do PowerShell
                #[derive(serde::Deserialize)]
                struct PsSoftware {
                    DisplayName: Option<String>,
                    DisplayVersion: Option<String>,
                    Publisher: Option<String>,
                    InstallDate: Option<String>
                }

                if let Ok(items) = serde_json::from_str::<Vec<PsSoftware>>(&json_str) {
                    for item in items {
                        software_list.push(SoftwareInfo {
                            name: item.DisplayName.unwrap_or_default(),
                            version: item.DisplayVersion.unwrap_or_else(|| "N/A".to_string()),
                            vendor: item.Publisher,
                            install_date: item.InstallDate,
                        });
                    }
                }
            }
        } else {
            // Mock Linux
            software_list.push(SoftwareInfo { name: "Vim".into(), version: "8.2".into(), vendor: None, install_date: None });
        }
        
        software_list
    }

    pub fn collect(&mut self) -> HostInfo {
        self.sys.refresh_cpu();
        self.sys.refresh_memory();
        self.sys.refresh_disks();
        self.sys.refresh_users_list();

        let hw_info = HardwareInfo {
            cpu_model: self.sys.cpus().first().map(|c| c.brand().to_string()).unwrap_or_default(),
            cpu_cores: self.sys.cpus().len(),
            ram_total_mb: self.sys.total_memory() / 1024 / 1024,
            ram_used_mb: self.sys.used_memory() / 1024 / 1024,
            disk_total_gb: self.sys.disks().iter().map(|d| d.total_space()).sum::<u64>() / 1024 / 1024 / 1024,
            disk_free_gb: self.sys.disks().iter().map(|d| d.available_space()).sum::<u64>() / 1024 / 1024 / 1024,
        };

        let logged_user = self.sys.users().first().map(|u| u.name().to_string()).unwrap_or_else(|| "unknown".to_string());

        HostInfo {
            hostname: self.sys.host_name().unwrap_or_default(),
            os_name: self.sys.name().unwrap_or_default(),
            os_version: self.sys.os_version().unwrap_or_default(),
            kernel_version: self.sys.kernel_version().unwrap_or_default(),
            arch: std::env::consts::ARCH.to_string(),
            logged_user,
            hardware: hw_info,
            peripherals: self.get_peripherals(),
            software: self.get_software(),
        }
    }
}
