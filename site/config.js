// Valores publicos do Supabase (podem ir para o GitHub: a seguranca esta nas regras da base de dados).
// Project URL: Supabase, Settings, API. Enquanto o URL estiver vazio, o site corre em modo demonstracao.
window.FRANVERA_CONFIG = {
  SUPABASE_URL: 'https://oufnoztwmusshqhwjblg.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_ns7MB8BcCNKVQLKe8WCDhQ_Fo5eUOIT',
  // Email tecnico de cada convidado (nunca recebe emails). Se o Supabase recusar com
  // "email address is invalid", troca por outro dominio real, por exemplo 'fv.{id}@outlook.com'.
  AUTH_EMAIL_TEMPLATE: 'fv.{id}@gmail.com',
  // Endereco do script que envia o link por email (Apps Script, ver apps-script/Code.gs). Vazio = sem email.
  MAIL_URL: 'https://script.google.com/macros/s/AKfycbyXXYvbrw1DcnU8p21m4OwIKZRTAYuhyg1fFRO5T01EWzJotoUad_Bu3kVBS5T5Ad3cEA/exec'
};
