// Este eh um pequeno utilitario para gerar chaves e assinar scripts manualmente para teste
use shared::crypto;
use std::io::Write;

fn main() {
    println!("ðŸ” Gerador de Chaves Blue-Taurus");
    let (priv_key, pub_key) = crypto::generate_keypair();
    
    println!("----------------------------------------------------------------");
    println!("GUARDE ISSO COM SUA VIDA (Em um Vault/Secret Manager):");
    println!("Private Key: {}", priv_key);
    println!("----------------------------------------------------------------");
    println!("COLOQUE ISSO NO CODIGO DO AGENTE (const ADMIN_PUBLIC_KEY):");
    println!("Public Key:  {}", pub_key);
    println!("----------------------------------------------------------------");

    // Salva em arquivos para facilitar
    let _ = std::fs::write("admin_private.key", priv_key);
    let _ = std::fs::write("agent_public.key", pub_key);
}
