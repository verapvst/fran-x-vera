/**
 * Pontuação normalizada da equipa: pontos totais ÷ nº de pessoas com pelo menos um check in.
 * Única função da fórmula, para ser fácil de mudar.
 */
export function teamScore(totalPoints: number, presentPeople: number): number {
  if (presentPeople <= 0) return 0;
  return totalPoints / presentPeople;
}
