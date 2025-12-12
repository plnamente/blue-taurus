use ed25519_dalek::{Verifier, SigningKey, VerifyingKey, Signature, Signer};
use rand::rngs::OsRng;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Falha ao decodificar chave ou assinatura")]
    DecodingError,
    #[error("Assinatura Invalida - POSSIVEL ATAQUE")]
    InvalidSignature,
}

/// Gera um par de chaves (Privada/Publica) para o Admin usar
pub fn generate_keypair() -> (String, String) {
    let mut csprng = OsRng;
    let signing_key = SigningKey::generate(&mut csprng);
    let verifying_key = signing_key.verifying_key();

    let priv_hex = hex::encode(signing_key.to_bytes());
    let pub_hex = hex::encode(verifying_key.to_bytes());

    (priv_hex, pub_hex)
}

/// Assina uma mensagem (script) usando a chave privada (Lado Server/Admin)
pub fn sign_message(private_key_hex: &str, message: &str) -> Result<String, CryptoError> {
    let priv_bytes = hex::decode(private_key_hex).map_err(|_| CryptoError::DecodingError)?;
    let signing_key = SigningKey::from_bytes(&priv_bytes.try_into().map_err(|_| CryptoError::DecodingError)?);
    
    let signature = signing_key.sign(message.as_bytes());
    Ok(hex::encode(signature.to_bytes()))
}

/// Verifica se a assinatura eh valida para aquela mensagem (Lado Agente)
pub fn verify_signature(public_key_hex: &str, message: &str, signature_hex: &str) -> Result<bool, CryptoError> {
    let pub_bytes = hex::decode(public_key_hex).map_err(|_| CryptoError::DecodingError)?;
    let verifying_key = VerifyingKey::from_bytes(&pub_bytes.try_into().map_err(|_| CryptoError::DecodingError)?)
        .map_err(|_| CryptoError::DecodingError)?;

    let sig_bytes = hex::decode(signature_hex).map_err(|_| CryptoError::DecodingError)?;
    let signature = Signature::from_bytes(&sig_bytes.try_into().map_err(|_| CryptoError::DecodingError)?);

    match verifying_key.verify(message.as_bytes(), &signature) {
        Ok(_) => Ok(true),
        Err(_) => Err(CryptoError::InvalidSignature),
    }
}
