/**
 * Device-local 4-digit PIN lock. The PIN is stored ONLY on the device
 * (localStorage), never on the server. After 15 minutes of inactivity the app
 * locks; unlocking requires the PIN. Users may disable the feature in settings.
 */
const IDLE_MS = 15 * 60 * 1000
const K_PIN = 'deskmate.pin'
const K_ENABLED = 'deskmate.pin.enabled'
const K_LAST = 'deskmate.pin.lastActive'

export function usePinLock() {
  const locked = useState('pin-locked', () => false)
  const hasPin = useState('pin-has', () => false)
  const enabled = useState('pin-enabled', () => false)

  function readLS(key: string) {
    return import.meta.client ? localStorage.getItem(key) : null
  }

  function init() {
    if (!import.meta.client) return
    hasPin.value = !!readLS(K_PIN)
    enabled.value = readLS(K_ENABLED) !== '0' && hasPin.value
    if (enabled.value) evaluateIdle()
  }

  function evaluateIdle() {
    if (!enabled.value || !hasPin.value) return
    const last = Number(readLS(K_LAST) || 0)
    if (last && Date.now() - last > IDLE_MS) locked.value = true
  }

  function touch() {
    if (import.meta.client) localStorage.setItem(K_LAST, String(Date.now()))
  }

  function setPin(pin: string) {
    if (!/^\d{4}$/.test(pin)) throw new Error('4자리 숫자를 입력해주세요')
    localStorage.setItem(K_PIN, pin)
    localStorage.setItem(K_ENABLED, '1')
    hasPin.value = true
    enabled.value = true
    touch()
  }

  function verify(pin: string): boolean {
    const ok = readLS(K_PIN) === pin
    if (ok) {
      locked.value = false
      touch()
    }
    return ok
  }

  function setEnabled(on: boolean) {
    enabled.value = on && hasPin.value
    localStorage.setItem(K_ENABLED, on ? '1' : '0')
    if (!on) locked.value = false
  }

  function removePin() {
    localStorage.removeItem(K_PIN)
    localStorage.setItem(K_ENABLED, '0')
    hasPin.value = false
    enabled.value = false
    locked.value = false
  }

  function lockNow() {
    if (enabled.value && hasPin.value) locked.value = true
  }

  return {
    locked,
    hasPin,
    enabled,
    init,
    evaluateIdle,
    touch,
    setPin,
    verify,
    setEnabled,
    removePin,
    lockNow,
  }
}
