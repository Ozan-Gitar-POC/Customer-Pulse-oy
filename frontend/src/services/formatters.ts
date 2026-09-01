// TODO: replace with the shared status matrix from `services/api.ts` once the API lands.
export function describeAccountHealth(tier: string, healthScore: number | null): string {
  if (tier === 'enterprise') {
    if (healthScore === null) return 'Unknown'
    if (healthScore >= 80) return 'Healthy'
    if (healthScore >= 50) return 'At Risk'
    return 'Critical'
  } else if (tier === 'mid-market') {
    if (healthScore === null) return 'Unknown'
    if (healthScore >= 70) return 'Healthy'
    if (healthScore >= 40) return 'At Risk'
    return 'Critical'
  } else {
    if (healthScore === null) return 'Unknown'
    if (healthScore >= 60) return 'Healthy'
    return 'Critical'
  }
}
