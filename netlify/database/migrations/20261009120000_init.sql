CREATE TABLE people (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'participant' CHECK (role IN ('participant', 'admin')),
  in_portugal BOOLEAN NOT NULL DEFAULT TRUE,
  team TEXT CHECK (team IN ('vera', 'fran')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE events (
  id TEXT PRIMARY KEY,
  day TEXT NOT NULL CHECK (day IN ('qui', 'sex', 'sab', 'dom')),
  start_time TEXT,
  end_time TEXT,
  all_day BOOLEAN NOT NULL DEFAULT FALSE,
  title TEXT NOT NULL,
  place TEXT,
  note TEXT,
  rule_text TEXT,
  official BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE challenges (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  points INTEGER NOT NULL DEFAULT 0 CHECK (points >= 0),
  event_id TEXT REFERENCES events(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE attendance_intent (
  person_id TEXT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  PRIMARY KEY (person_id, event_id)
);

CREATE TABLE login_attempts (
  ip TEXT NOT NULL,
  at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX login_attempts_ip_at ON login_attempts (ip, at);

-- Programa oficial. Não alterar horários.
INSERT INTO events (id, day, start_time, end_time, all_day, title, place, note, rule_text, official, sort_order) VALUES
  ('e1',  'qui', '19:00', '23:30', FALSE, 'THE GRAND OPENING', 'Corner', 'Início oficial da festa, apresentação do conceito, equipas e jogo.', NULL, TRUE, 1),
  ('e2',  'sex', '00:00', '00:30', FALSE, '23.', NULL, 'Momento de aniversário da Fran.', NULL, TRUE, 2),
  ('e3',  'sex', '00:30', '02:00', FALSE, 'PRAIA NO PARQUE', NULL, NULL, NULL, TRUE, 3),
  ('e4',  'sex', '02:00', '18:00', FALSE, 'WORK DAY', NULL, 'Dia normal de trabalho. Não é programação oficial da festa.', NULL, FALSE, 4),
  ('e5',  'sex', '19:00', '23:00', FALSE, 'RALLY TASCAS & CROQUETTE', 'Belém → Bairro Alto', 'Um rally pelas tascas, com diferentes challenges e pontos ao longo do percurso.', NULL, TRUE, 5),
  ('e6',  'sex', '23:00', '02:00', FALSE, 'ZÉ DOS BOIS', NULL, NULL, NULL, TRUE, 6),
  ('e7',  'sab', NULL, NULL, TRUE, 'RECOVERY DAY', NULL, NULL, NULL, TRUE, 7),
  ('e8',  'sab', '20:00', '22:00', FALSE, 'BINGO', NULL, 'Evento especial com sistema de pontuação próprio.', 'Linha: X pontos · Bingo: 100 pontos', TRUE, 8),
  ('e9',  'sab', '22:00', '00:00', FALSE, 'PRE-DRINKS', NULL, NULL, NULL, TRUE, 9),
  ('e10', 'dom', '00:00', '00:30', FALSE, '24.', NULL, 'Momento de aniversário da Vera.', NULL, TRUE, 10),
  ('e11', 'dom', '00:30', '06:00', FALSE, 'THE FINALE', NULL, NULL, NULL, TRUE, 11);

INSERT INTO challenges (id, text, points) VALUES
  ('c1', '[Nome A] tem de convencer [Nome B] a tirar uma foto a fazer X.', 30),
  ('c2', 'Três pessoas da tua equipa numa só foto, a imitar a mesma pose.', 20);
