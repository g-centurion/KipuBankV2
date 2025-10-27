# KipuBankV2: Plataforma de Bóveda Descentralizada Multi-Token y Multi-Rol

El proyecto KipuBankV2 representa la evolución a un contrato de producción a partir del contrato base KipuBank del Módulo 2. Este contrato simula una bóveda segura que gestiona depósitos en activos nativos (ETH) y tokens ERC-20, utilizando infraestructura descentralizada (Chainlink) para la validación de límites de valor.

El código actualizado del contrato se encuentra en la carpeta /src.

**URL del Contrato Desplegado y verificado en Sepolia:** 
  https://sepolia.etherscan.io/address/0x1a74a3A02a1868813Bd62D74F30A63efCA584912        
  https://eth-sepolia.blockscout.com/address/0x1a74a3A02a1868813Bd62D74F30A63efCA584912?tab=contract
  https://testnet.routescan.io/address/0x1a74a3A02a1868813Bd62D74F30A63efCA584912/contract/11155111/code
  https://repo.sourcify.dev/11155111/0x1a74a3A02a1868813Bd62D74F30A63efCA584912

---

## Mejoras de Arquitectura y Razones de Diseño

La refactorización de KipuBank a KipuBankV2 se centró en mejorar la seguridad, la escalabilidad (soporte multi-token) y la solidez financiera (límites basados en USD), cumpliendo con los requisitos avanzados del proyecto.

<details>
<summary>Ver Detalles de Arquitectura y Patrones de Diseño</summary>

| Área de Mejora | Implementación en KipuBankV2 | Razón de la Decisión / Patrón de Diseño |
| :--- | :--- | :--- |
| **Control de Acceso** | Uso de `AccessControl` de OpenZeppelin. Roles definidos (`PAUSE_MANAGER_ROLE`, `CAP_MANAGER_ROLE`, `TOKEN_MANAGER_ROLE`). | Migración del patrón simple `onlyOwner` a RBAC (Control de Acceso Basado en Roles). Esto aplica el Principio de Mínimo Privilegio a las tareas administrativas, mejorando la seguridad. |
| **Soporte Multi-token** | Mapeos anidados (`balances[address user][address token]`) y uso de `address(0)` para ETH. | Permite la contabilidad interna de múltiples activos ERC-20 y ETH, haciendo la bóveda más versátil. |
| **Seguridad ERC-20** | Uso de la librería `SafeERC20` de OpenZeppelin (`safeTransferFrom`, `safeTransfer`). | Garantiza interacciones seguras con tokens que podrían no implementar el estándar ERC-20 correctamente. |
| **Límite Global** | Integración de Chainlink Data Feeds (`AggregatorV3Interface`) y constante `BANK_CAP_USD`. Implementación de la función `_getUsdValueFromWei`. | El límite global de depósitos se controla en dólares estadounidenses (USD), no en un valor volátil de ETH, proporcionando estabilidad financiera al protocolo. |
| **Aritmética Segura** | Utiliza la regla de "multiplicar antes de dividir" para manejar la conversión de decimales de Wei ($10^{18}$) a Chainlink USD ($10^8$). | Evita errores de truncamiento y pérdida de precisión. |
| **Pausabilidad** | Herencia de `Pausable` de OpenZeppelin. Funciones protegidas con `whenNotPaused`. | Provee un interruptor de emergencia (Emergency Stop) para mitigar rápidamente ataques de Denegación de Servicio (DoS) o vulnerabilidades críticas, controlado por el `PAUSE_MANAGER_ROLE`. |
| **Eficiencia de Gas** | Uso de variables `constant` (`BANK_CAP_USD`) e `immutable` (`MAX_WITHDRAWAL_PER_TX`) y bloques `unchecked`. | Minimiza el costo de lectura de variables de estado (no requiere `SLOAD`) y optimiza el gas para operaciones de contadores. |

</details>

---

## Decisiones de Diseño Importantes (Trade-offs)

<details>
<summary>Ver Decisiones de Implementación y Trade-offs</summary>

### 1. Patrón Checks-Effects-Interactions (CEI)
El contrato aplica rigurosamente el patrón CEI para mitigar ataques de Reentrancy.
* En la función `withdraw`, el saldo del usuario se decrementa (`balances[msg.sender] = ...`) en la sección *Effects* antes de realizar la llamada externa (`call{value: amountToWithdraw}("")`) en la sección *Interactions*.

### 2. Transferencias Nativas Seguras
Para las transferencias de Ether, se utiliza la llamada de bajo nivel `call` en lugar de `transfer` o `send`.
* **Razón:** `transfer` y `send` están limitados a 2300 unidades de gas, lo que puede causar fallos si el receptor es un contrato inteligente con lógica de fallback más compleja. El uso de `call` minimiza esta limitación y es considerado la práctica moderna y segura.

### 3. Precisión Aritmética y Conversión de Decimales
La función interna `_getUsdValueFromWei` es crucial para la lógica de límites.
* La conversión de ETH (18 decimales) al precio de Chainlink USD (8 decimales) requiere manejar la disparidad en la precisión.
* La fórmula `(ethAmount * ethPriceUsd) / 10**18` aplica la técnica de multiplicar antes de dividir para preservar la precisión y evitar el truncamiento a cero de números pequeños, un error común en Solidity.

### 4. Uso de `unchecked` para Optimización
Se utiliza el bloque `unchecked` en la sección *Effects* de `deposit()` y `withdraw()` para operaciones donde la seguridad ya ha sido verificada en los *Checks*.
* Específicamente, `_depositCount++` se envuelve en `unchecked`. Dado que el contador solo se incrementa, no hay riesgo de overflow que comprometa la lógica de negocio; esta omisión de comprobación de desbordamiento acelera la ejecución y reduce el costo de gas.

</details>

---

## Instrucciones de Despliegue e Interacción

<details>
<summary>Ver Instrucciones de Despliegue e Interacción</summary>

El contrato KipuBankV2 se debe desplegar en una testnet (como Sepolia) que sea compatible con los Data Feeds de Chainlink. Se recomienda utilizar Remix IDE conectado a MetaMask (`Injected Provider - MetaMask`) para la interacción.

### 1. Requisitos del Constructor
El contrato requiere dos argumentos obligatorios en el momento del despliegue:

| Parámetro | Tipo | Descripción | Ejemplo (Sepolia) |
| :--- | :--- | :--- | :--- |
| `priceFeedAddress` | `address` | Dirección del oráculo ETH/USD de Chainlink en la red de destino. | `0x694AA1769357215Ef4bEca1d26543d95Bdc24Ff6` |
| `maxWithdrawalAmount` | `uint256` | Límite máximo (en Wei) que un usuario puede retirar por transacción. | `1000000000000000000` (1 ETH) |


**Nota sobre Roles:** La dirección que realiza el despliegue (`msg.sender` en el constructor) recibe automáticamente todos los roles administrativos: `DEFAULT_ADMIN_ROLE`, `CAP_MANAGER_ROLE`, `TOKEN_MANAGER_ROLE`, y `PAUSE_MANAGER_ROLE`.

### 2. Interacción con Funcionalidades Clave

| Funcionalidad | Función | Rol Requerido | Notas de Interacción |
| :--- | :--- | :--- | :--- |
| Depósito ETH | `deposit()` | Cualquiera | Función `external payable`. Debe ser llamada con valor (`msg.value`). El contrato verifica el límite de $1,000,000 USD. |
| Retiro ETH | `withdraw(amount)` | Cualquiera | La cantidad debe respetar `MAX_WITHDRAWAL_PER_TX` y el saldo del usuario. |
| Administración | `setEthPriceFeedAddress(addr)` | `CAP_MANAGER_ROLE` | Permite actualizar la dirección del oráculo. |
| Añadir Token | `addSupportedToken(token, priceFeed, dec)` | `TOKEN_MANAGER_ROLE` | Registra un nuevo token ERC-20 y su oráculo asociado. |
| Depósito ERC-20 | `depositToken(token, amount)` | Cualquiera | Requiere que el usuario haya llamado `approve()` previamente en el contrato del token, ya que usa `safeTransferFrom`. |
| Parada de Emergencia | `pause() / unpause()` | `PAUSE_MANAGER_ROLE` | Detiene/reactiva todas las funciones transaccionales protegidas por `whenNotPaused`. |

</details>

---

## Casos de Prueba: KipuBankV2

<details>
<summary><strong> Casos de Prueba detallados </strong></summary>

### Contexto de Prueba
| Contexto | Descripción |
| :--- | :--- |
| Cuentas | ADMIN (Tu cuenta, posee todos los roles) y USUARIO B (Otra cuenta con fondos de prueba). |
| Token de Prueba | Usaremos un token de prueba (Mock Token) con 18 decimales, registrado bajo el oráculo DAI/USD de Sepolia. |
| Límite de Retiro | `MAX_WITHDRAWAL_PER_TX`: `1000000000000000000` (1 ETH en Wei, variable `immutable`). |
| Límite Global | `BANK_CAP_USD`: $1,000,000 USD (variable `constant` con $10^8$ decimales). |
<br>

<details>
<summary><strong>FASE 1: Validación del Control de Acceso (TOKEN_MANAGER_ROLE)</strong></summary>
<p>Objetivo: Verificar que solo el <code>TOKEN_MANAGER_ROLE</code> (ADMIN) puede agregar tokens al catálogo. Esto valida el control de acceso y las Declaraciones de Tipos (struct <code>TokenData</code>).</p>

| ID | Función/Rol a Probar | Cuenta | Entradas Requeridas | Resultado Esperado | Verificación |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1.1 | `addSupportedToken` (Restringida) | ADMIN | `tokenAddress`: `0x1111111111111111111111111111111111111111` (Dirección de Prueba) <br> `priceFeedAddress`: `0x1486940d5E31A21e25e22C66e92751505A4b23b8` (Oráculo DAI/USD Sepolia) <br> `decimals`: 18 | Éxito. La transacción es confirmada. | Se emite el evento `TokenSupported`. Confirma que el ADMIN puede ejecutar funciones restringidas. |
| 1.2 | `addSupportedToken` (Violación de Rol) | USUARIO B | Mismos parámetros que 1.1. | REVERTIR. | La transacción falla con un error de `AccessControl` o un error personalizado `Bank__Unauthorized`. |
</details>

<details>
<summary><strong>FASE 2: Conversión de Valores y Límite Global (Oráculos)</strong></summary>
<p>Objetivo: Probar la función <code>deposit()</code>. La lógica de negocio ahora debe usar Chainlink para convertir ETH/Wei ($10^{18}$ decimales) a USD ($10^8$ decimales) y aplicar el límite global.</p>

| ID | Función a Probar | Cuenta | Acción y Valor de Entrada | Resultado Esperado | Verificación Crítica |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2.1 | `deposit()` (Éxito) | USUARIO B | `Value`: 0.1 ETH (Gas: Estándar) | Éxito. | Se emite `DepositSuccessful`. <br> Verificar `getDepositCount()` (debe aumentar). <br> Verificar `balances[USUARIO B][address(0)]` (Mapeo anidado). |
| 2.2 | `deposit()` (Fallo: Límite Global) | USUARIO B | `Value`: 5000 ETH (Un valor que exceda $1M USD, asumiendo un precio ETH alto) | REVERTIR. | La transacción falla con el error personalizado `Bank__DepositExceedsCap`. Confirma que el oráculo de Chainlink y la Función de conversión de decimales funcionan. |
</details>

<details>
<summary><strong>FASE 3: Interacción Multi-Token (Mappings Anidados y CEI)</strong></summary>
<p>Objetivo: Usar el token registrado en el Catálogo (<code>0x111...111</code>) para probar el sistema de contabilidad multi-token, basado en Mappings anidados.</p>

| ID | Función a Probar | Cuenta | Entradas Requeridas | Resultado Esperado | Verificación Crítica |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 3.1 | `depositToken` | USUARIO B | `tokenAddress`: `0x111...111` <br> `amount`: `500000000000000000` (0.5 Token) | Éxito (asumiendo `approve()` previo). | Mapeo Anidado: Verificar `balances[USUARIO B][0x111...111]`. Debe ser 0.5 Token. |
| 3.2 | `withdrawToken` (Fallo: Límite `immutable`) | USUARIO B | `tokenAddress`: `0x111...111` <br> `amount`: `2000000000000000000` (2 Token) | REVERTIR. | Falla con `Bank__WithdrawalExceedsLimit`. Confirma el cumplimiento de la variable `MAX_WITHDRAWAL_PER_TX` (`immutable`). |
| 3.3 | `withdrawToken` (Éxito y CEI) | USUARIO B | `tokenAddress`: `0x111...111` <br> `amount`: `100000000000000000` (0.1 Token) | Éxito. | Patrón CEI: El saldo en el mapeo anidado (`balances`) se resta (Effect) antes de que se ejecute la transferencia de tokens (Interaction). Verificar que el nuevo saldo es 0.4 Token. |
</details>

<details>
<summary><strong>FASE 4: Pausabilidad y Mitigación DoS (PAUSE_MANAGER_ROLE)</strong></summary>
<p>Objetivo: Probar el interruptor de emergencia (<code>Pausable</code>), que mitiga los ataques de Denegación de Servicio (DoS).</p>

| ID | Acción | Función | Cuenta | Entradas | Resultado Esperado | Verificación Crítica |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 4.1 | Activar Emergencia | `pause()` (Write Contract) | ADMIN | N/A | Transacción Exitosa. | El contrato está ahora en estado `paused`. |
| 4.2 | Prueba de Bloqueo | `deposit()` | USUARIO B | `Value`: 0.01 ETH | REVERTIR. | Falla con un error de `Pausable` (error de `whenNotPaused`). Esto valida que el Control de Acceso y la arquitectura de seguridad detienen las funciones críticas. |
| 4.3 | Desactivar Emergencia | `unpause()` (Write Contract) | ADMIN | N/A | Transacción Exitosa. | El contrato regresa a estado activo. |
| 4.4 | Reanudación | `deposit()` | USUARIO B | `Value`: 0.01 ETH | Éxito. | Se confirma que el flujo de negocio se reanuda correctamente. |
</details>

