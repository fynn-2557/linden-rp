'use strict';
// NRW-based display catalog. Gameplay tiers are not civil-service appointments.
// Higher-grade titles and RP qualification checks are managed separately.
const RANKS = Object.freeze({
  police: [
    'Polizeikommissar/-in', 'Polizeioberkommissar/-in',
    'Polizeihauptkommissar/-in', 'Erste/-r Polizeihauptkommissar/-in',
    'Polizeirat/-rätin', 'Polizeioberrat/-rätin',
    'Polizeidirektor/-in', 'Leitende/-r Polizeidirektor/-in'
  ],
  fire: [
    'Brandmeister/-in', 'Oberbrandmeister/-in', 'Hauptbrandmeister/-in',
    'Brandinspektor/-in', 'Brandoberinspektor/-in',
    'Brandamtmann/-frau', 'Brandamtsrat/-rätin',
    'Brandoberamtsrat/-rätin', 'Brandrat/-rätin',
    'Brandoberrat/-rätin', 'Branddirektor/-in'
  ],
  // These are qualification levels, NOT a German ambulance "rank" ladder.
  ems: [
    'Rettungsdienst-Anwärter/-in (RP)', 'Rettungshelfer/-in',
    'Rettungssanitäter/-in', 'Notfallsanitäter/-in'
  ],
  civilian: ['Zivilist/-in']
});
const FF_RANKS = Object.freeze([
  'Feuerwehranwärter/-in', 'Feuerwehrmann/-frau',
  'Oberfeuerwehrmann/-frau', 'Hauptfeuerwehrmann/-frau',
  'Unterbrandmeister/-in', 'Brandmeister/-in',
  'Oberbrandmeister/-in', 'Hauptbrandmeister/-in',
  'Brandinspektor/-in', 'Brandoberinspektor/-in',
  'Stadtbrandinspektor/-in'
]);
module.exports={RANKS,FF_RANKS};
