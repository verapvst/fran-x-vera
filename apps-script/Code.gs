// FRAN x VERA: envia a cada convidado o link pessoal por email, a partir do Gmail de quem publica este script.
// O site chama este script depois de a pessoa criar o perfil. O script nunca recebe o email nem o link do site:
// recebe apenas a sessao da pessoa, confirma-a no Supabase e envia para o email que a propria pessoa registou.
// Valores publicos (podem ficar no GitHub): o URL e a chave publishable do Supabase.
var SUPABASE_URL = 'https://oufnoztwmusshqhwjblg.supabase.co';
var SUPABASE_KEY = 'sb_publishable_ns7MB8BcCNKVQLKe8WCDhQ_Fo5eUOIT';
var SITE = 'https://verapvst.github.io/fran-x-vera/';
var MAX_POR_DIA = 3;   // emails por pessoa por dia

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    var tok = String(body.token || '');
    if (body.action === 'challenges') return avisarChallenges_(tok, body.ids);
    if (body.action === 'broadcast') return avisarTodos_(tok, String(body.kind || ''), String(body.target || ''));
    if (tok.length < 20) return out_({ok: false, error: 'sem sessao'});
    var h = {apikey: SUPABASE_KEY, Authorization: 'Bearer ' + tok};
    var ru = UrlFetchApp.fetch(SUPABASE_URL + '/auth/v1/user', {headers: h, muteHttpExceptions: true});
    if (ru.getResponseCode() !== 200) return out_({ok: false, error: 'sessao invalida'});
    var uid = JSON.parse(ru.getContentText()).id;
    var rk = UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/member_keys?select=link_key,contact&user_id=eq.' + encodeURIComponent(uid), {headers: h, muteHttpExceptions: true});
    var rows = JSON.parse(rk.getContentText());
    if (!rows || !rows.length || !rows[0].contact || !rows[0].link_key) return out_({ok: false, error: 'sem email'});
    var rp = UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/profiles?select=name&id=eq.' + encodeURIComponent(uid), {headers: h, muteHttpExceptions: true});
    var prof = JSON.parse(rp.getContentText());
    var name = (prof && prof[0] && prof[0].name) ? prof[0].name : '';

    // limite por pessoa e por dia
    var lock = LockService.getScriptLock(); lock.waitLock(10000);
    try {
      var props = PropertiesService.getScriptProperties();
      var day = Utilities.formatDate(new Date(), 'Europe/Lisbon', 'yyyyMMdd');
      var key = 'n_' + uid + '_' + day;
      var n = parseInt(props.getProperty(key) || '0', 10);
      if (n >= MAX_POR_DIA) return out_({ok: false, error: 'limite'});
      props.setProperty(key, String(n + 1));
    } finally { lock.releaseLock(); }

    var link = SITE + '?k=' + rows[0].link_key;
    var codigo = rows[0].link_key;
    var first = name ? name.split(' ')[0] : '';
    var texto = 'Olá' + (first ? ' ' + first : '') + '!\n\n' +
      'Este é o teu link pessoal para a festa FRAN × VERA (15 a 18 de outubro, Lisboa):\n\n' + link + '\n\n' +
      'Abre-o em qualquer telemóvel e entras logo como tu, sem password. Guarda este email. Só tu deves ter este link: quem o tiver entra como tu.\n\n' +
      'Se o link não te levar ao teu perfil, abre o site, vai a Entrar, escolhe "Já tenho o meu link" e cola este código: ' + codigo + '\n\n' +
      'Até já,\nFran e Vera';
    var html = '<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:auto;padding:24px;background:#f4e2ea;color:#0d0a0b">' +
      '<h2 style="margin:0 0 12px;font-size:22px">FRAN × VERA · 23H30 DE FESTA</h2>' +
      '<p>Olá' + (first ? ' ' + esc_(first) : '') + '!</p>' +
      '<p>Este é o teu link pessoal para a festa (15 a 18 de outubro, Lisboa). Abre-o em qualquer telemóvel e entras logo como tu, sem password.</p>' +
      '<p style="margin:22px 0"><a href="' + link + '" style="background:#e8421f;color:#0d0a0b;text-decoration:none;font-weight:bold;padding:14px 22px;border-radius:999px;border:2px solid #0d0a0b">Abrir o meu link</a></p>' +
      '<p style="font-size:13px;word-break:break-all">Se o botão não abrir, copia este endereço:<br>' + esc_(link) + '</p>' +
      '<p style="font-size:13px">Se o link não te levar ao teu perfil: no site, Entrar, "Já tenho o meu link", e cola este código:<br><b>' + esc_(codigo) + '</b></p>' +
      '<p style="font-size:13px">Guarda este email. Só tu deves ter este link: quem o tiver entra como tu.</p>' +
      '<p>Até já,<br>Fran e Vera</p></div>';
    MailApp.sendEmail(rows[0].contact, 'O teu link para a festa FRAN × VERA', texto, {htmlBody: html, name: 'FRAN × VERA'});
    return out_({ok: true});
  } catch (err) {
    return out_({ok: false, error: String(err)});
  }
}

function doGet() { return out_({ok: true, info: 'FRAN x VERA mailer'}); }
function out_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }
function esc_(s) { return String(s).replace(/[&<>"']/g, function (c) { return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[c]; }); }


// Referees: avisa por email cada pessoa que recebeu challenges novos. O email nunca diz o que é o challenge (pode ser secreto),
// só que há novidades, com o link pessoal. Só corre para sessões de referee, confirmadas no Supabase.
// ids (opcional): só avisa estes challenges. Sem ids, avisa todos os que ainda não foram avisados (botão "Avisar por email").
function avisarChallenges_(tok, ids) {
  if (tok.length < 20) return out_({ok: false, error: 'sem sessao'});
  var h = {apikey: SUPABASE_KEY, Authorization: 'Bearer ' + tok};
  var ru = UrlFetchApp.fetch(SUPABASE_URL + '/auth/v1/user', {headers: h, muteHttpExceptions: true});
  if (ru.getResponseCode() !== 200) return out_({ok: false, error: 'sessao invalida'});
  var uid = JSON.parse(ru.getContentText()).id;
  var rr = JSON.parse(UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/profiles?select=role&id=eq.' + encodeURIComponent(uid), {headers: h, muteHttpExceptions: true}).getContentText());
  if (!rr || !rr.length || rr[0].role !== 'referee') return out_({ok: false, error: 'so referees'});

 var soIds = '';
  if (ids && ids.length) {
    var bons = ids.filter(function (x) { return /^[0-9a-f-]{36}$/i.test(String(x)); });
    if (!bons.length) return out_({ok: true, sent: 0});
    soIds = '&id=in.(' + bons.join(',') + ')';
  }
  var as = JSON.parse(UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/assignments?select=id,user_id&notified=eq.false&status=eq.open&limit=500' + soIds, {headers: h, muteHttpExceptions: true}).getContentText());
  if (!as || !as.length) return out_({ok: true, sent: 0});
  var porPessoa = {};
  as.forEach(function (a) { (porPessoa[a.user_id] = porPessoa[a.user_id] || []).push(a.id); });
  var ids = Object.keys(porPessoa);
  var lista = '(' + ids.join(',') + ')';
  var keys = JSON.parse(UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/member_keys?select=user_id,contact,link_key&user_id=in.' + lista, {headers: h, muteHttpExceptions: true}).getContentText());
  var nomes = JSON.parse(UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/profiles?select=id,name&id=in.' + lista, {headers: h, muteHttpExceptions: true}).getContentText());
  var nome = {}; nomes.forEach(function (p) { nome[p.id] = p.name; });
  var enviados = 0, feitos = [];
  keys.forEach(function (k) {
    if (!k.contact) return;
    var n = porPessoa[k.user_id].length, first = nome[k.user_id] ? String(nome[k.user_id]).split(' ')[0] : '';
    var link = SITE + (k.link_key ? '?k=' + k.link_key : '');
    var codigo = k.link_key || '';
    var texto = 'Olá' + (first ? ' ' + first : '') + '!\n\nTens ' + (n === 1 ? 'um challenge novo' : n + ' challenges novos') + ' na festa FRAN × VERA. Abre o site, vai a Challenges, cumpre-o e envia a prova (foto ou vídeo) para ganhares pontos para a tua equipa.\n\n' + link + '\n\nFran e Vera';
    var html = '<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:auto;padding:24px;background:#f4e2ea;color:#0d0a0b">' +
      '<h2 style="margin:0 0 12px;font-size:22px">FRAN × VERA</h2><p>Olá' + (first ? ' ' + esc_(first) : '') + '!</p>' +
      '<p>Tens <b>' + (n === 1 ? 'um challenge novo' : n + ' challenges novos') + '</b>. Cumpre-' + (n === 1 ? 'o' : 'os') + ' e envia a prova (foto ou vídeo) para ganhares pontos para a tua equipa.</p>' +
      '<p style="margin:22px 0"><a href="' + link + '" style="background:#e8421f;color:#0d0a0b;text-decoration:none;font-weight:bold;padding:14px 22px;border-radius:999px;border:2px solid #0d0a0b">Ver os meus challenges</a></p>' +
      '<p style="font-size:13px">Se o link não te levar ao teu perfil: no site, Entrar, "Já tenho o meu link", e cola este código:<br><b>' + esc_(codigo) + '</b></p><p>Fran e Vera</p></div>';
    try {
      MailApp.sendEmail(k.contact, 'Tens um challenge novo | FRAN × VERA', texto, {htmlBody: html, name: 'FRAN × VERA'});
      enviados++; feitos = feitos.concat(porPessoa[k.user_id]);
    } catch (err) { /* limite do Gmail: fica por avisar e tenta-se outra vez */ }
  });
  if (feitos.length) {
    UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/rpc/mark_notified', {method: 'post', contentType: 'application/json', headers: h, payload: JSON.stringify({p_ids: feitos}), muteHttpExceptions: true});
  }
  return out_({ok: true, sent: enviados});
}

// Referees: envia um aviso por email a toda a gente que criou conta (e tem email). Cada pessoa recebe cada aviso uma só vez
// (se carregares duas vezes, ou se o limite diário do Gmail cortar a meio, só se envia a quem falta).
var AVISOS = {
  'dia2': {
    assunto: 'O segundo dia está on! O BoozeFeed já funciona | FRAN × VERA',
    linhas: ['O segundo dia está on!',
             'O BoozeFeed já está a funcionar (ontem não estava, desculpem). Hoje não se esqueçam de postar, beber e divertirem-se muito.',
             'Este é o teu link pessoal. Se tinhas um link antigo ou que não te levou ao teu perfil, usa este, que é o certo.'],
    botao: 'Abrir o BoozeFeed'
  },
  'boozefeed': {
    assunto: 'O BoozeFeed já está a funcionar | FRAN × VERA',
    linhas: ['O BoozeFeed já está funcional!',
             'Abre o site, vai ao BoozeFeed e faz o teu primeiro post (selfie e bebida). Ficas logo numa equipa para as noites todas e ganhas pontos por cada bebida e por cada hora que ficares na festa.'],
    botao: 'Abrir o BoozeFeed'
  }
};

function avisarTodos_(tok, kind, target) {
  var aviso = AVISOS[kind];
  if (!aviso) return out_({ok: false, error: 'aviso desconhecido'});
  if (tok.length < 20) return out_({ok: false, error: 'sem sessao'});
  var h = {apikey: SUPABASE_KEY, Authorization: 'Bearer ' + tok};
  var ru = UrlFetchApp.fetch(SUPABASE_URL + '/auth/v1/user', {headers: h, muteHttpExceptions: true});
  if (ru.getResponseCode() !== 200) return out_({ok: false, error: 'sessao invalida'});
  var uid = JSON.parse(ru.getContentText()).id;
  var rr = JSON.parse(UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/profiles?select=role&id=eq.' + encodeURIComponent(uid), {headers: h, muteHttpExceptions: true}).getContentText());
  if (!rr || !rr.length || rr[0].role !== 'referee') return out_({ok: false, error: 'so referees'});

  var keys = JSON.parse(UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/member_keys?select=user_id,contact,link_key&limit=1000', {headers: h, muteHttpExceptions: true}).getContentText());
  var nomes = JSON.parse(UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/profiles?select=id,name&limit=1000', {headers: h, muteHttpExceptions: true}).getContentText());
  var nome = {}; nomes.forEach(function (p) { nome[p.id] = p.name; });
  var props = PropertiesService.getScriptProperties();
  var enviados = 0, jaTinham = 0, semEmail = 0, cortou = false;
  keys.forEach(function (k) {
    if (target && k.user_id !== target) return;   // teste a uma só pessoa
    if (!k.contact) { semEmail++; return; }
    var chave = 'bc_' + kind + '_' + k.user_id;
    if (!target && props.getProperty(chave)) { jaTinham++; return; }   // o envio a toda a gente não repete; o teste a uma pessoa envia sempre
    if (MailApp.getRemainingDailyQuota() < 1) { cortou = true; return; }
    var first = nome[k.user_id] ? String(nome[k.user_id]).split(' ')[0] : '';
    var link = SITE + (k.link_key ? '?k=' + k.link_key : '');
    var codigo = k.link_key || '';
    var texto = 'Olá' + (first ? ' ' + first : '') + '!\n\n' + aviso.linhas.join('\n\n') + '\n\n' + link + '\n\nSe o link não te levar ao teu perfil, abre o site, Entrar, "Já tenho o meu link", e cola este código: ' + codigo + '\n\nFran e Vera';
    var html = '<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:auto;padding:24px;background:#f4e2ea;color:#0d0a0b">' +
      '<h2 style="margin:0 0 12px;font-size:22px">FRAN × VERA</h2><p>Olá' + (first ? ' ' + esc_(first) : '') + '!</p>' +
      aviso.linhas.map(function (l) { return '<p>' + esc_(l) + '</p>'; }).join('') +
      '<p style="margin:22px 0"><a href="' + link + '" style="background:#e8421f;color:#0d0a0b;text-decoration:none;font-weight:bold;padding:14px 22px;border-radius:999px;border:2px solid #0d0a0b">' + esc_(aviso.botao) + '</a></p>' +
      '<p style="font-size:13px">Se o link não te levar ao teu perfil: no site, Entrar, "Já tenho o meu link", e cola este código:<br><b>' + esc_(codigo) + '</b></p><p>Fran e Vera</p></div>';
    try {
      MailApp.sendEmail(k.contact, aviso.assunto, texto, {htmlBody: html, name: 'FRAN × VERA'});
      props.setProperty(chave, '1'); enviados++;
    } catch (err) { cortou = true; }
  });
  return out_({ok: true, sent: enviados, already: jaTinham, noEmail: semEmail, quotaHit: cortou});
}
