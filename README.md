# KipuBankV2: Bóveda Multi-Token con Control de Acceso y Oráculos Chainlink

**URL del Contrato Desplegado en Sepolia:** [https://sepolia.etherscan.io/address/0x70A910C10fAE01802f1aB9798773275B67aE5710]

---

## 1. Explicación a Alto Nivel de las Mejoras

`KipuBankV2` es la refactorización del contrato `KipuBank` original, evolucionando su arquitectura para cumplir con estándares de producción en términos de seguridad, control de acceso y escalabilidad.

Las mejoras clave del Módulo 3 son:

| Componente | Descripción de la Mejora | Fuente |
| :--- | :--- | :--- |
| **Control de Acceso (Roles)** | Implementación de `AccessControl` de OpenZeppelin para delegar permisos de forma granular, incluyendo `CAP_MANAGER_ROLE`, `TOKEN_MANAGER_ROLE`, y `PAUSE_MANAGER_ROLE`. | Requisito M3. |
| **Oráculos de Chainlink** | Integración de Chainlink Data Feeds para convertir el valor de ETH a USD, permitiendo que el límite global (`BANK_CAP_USD`) se aplique en dólares, y no en unidades de ETH volátiles. | Requisito M3. |
| **Soporte Multi-token** | El contrato ahora soporta depósitos y retiros de tokens ERC-20, utilizando un catálogo administrado (`s_tokenCatalog`) y mappings anidados (`balances`) para llevar la contabilidad por token. | Requisito M3. |
| **Seguridad de Emergencia** | Herencia del contrato `Pausable` de OpenZeppelin, gestionado por el `PAUSE_MANAGER_ROLE`, para detener las funciones críticas (`deposit`, `withdraw`) ante amenazas de seguridad o fallos de oráculo. | Patrón de Seguridad. |

---

## 2. Instrucciones de Despliegue e Interacción

El código final se encuentra en la carpeta `/src/KipuBankV2.sol`.

### A. Despliegue

1.  **Entorno:** Utilizar Remix IDE, conectado a la red de prueba Sepolia a través de Injected Provider (MetaMask).
2.  **Versión del Compilador:** Solidity `^0.8.26`.
3.  **Argumentos del Constructor:** Se requieren dos argumentos para la inicialización:
    * `priceFeedAddress (address)`: La dirección del Data Feed ETH/USD en Sepolia.
        * *Valor de Ejemplo (Sepolia):* `0x694AA1769357215Ef4bE215cd2aa0325eEba1cda`
    * `maxWithdrawalAmount (uint256)`: El límite máximo de retiro por transacción, expresado en Wei.
        * *Valor de Ejemplo (1 ETH):* `1000000000000000000`

### B. Interacción (Funcionalidades Clave)

Todas las interacciones se realizan a través de la interfaz de Remix o Etherscan ("Write Contract").

| Rol / Usuario | Función | Propósito |
| :--- | :--- | :--- |
| Desplegador | `addSupportedToken()` | Registrar nuevos tokens ERC-20 y sus oráculos de Chainlink (ejecutado por `TOKEN_MANAGER_ROLE`). |
| Desplegador | `pause()` / `unpause()` | Activar/desactivar el interruptor de emergencia (ejecutado por `PAUSE_MANAGER_ROLE`). |
| Usuario | `deposit()` | Depositar ETH. Requiere `value` (ETH) y verifica el `BANK_CAP_USD` usando el oráculo. |
| Usuario | `withdrawToken()` | Retirar tokens ERC-20, sujeto al límite `MAX_WITHDRAWAL_PER_TX`. |

---

## 3. Decisiones de Diseño Importantes y Trade-offs

### A. Seguridad y Patrones

* **Patrón CEI estricto:** Todas las funciones transaccionales (`deposit`, `withdraw`, `withdrawToken`) siguen el patrón Checks-Effects-Interactions para prevenir ataques de reentrada. La actualización de saldos (EFFECTS) ocurre siempre antes de la transferencia externa (INTERACTIONS).
* **Manejo Seguro de Transferencias:** Se utiliza `SafeERC20` para tokens ERC-20 y el método de bajo nivel `.call{value: amount}("")` para transferencias de ETH nativo.
* **Errores Personalizados:** Se emplean Custom Errors (`error Bank__...`) en lugar de `require(..., "string")`, lo que mejora la legibilidad, la capacidad de depuración y optimiza el gas.

### B. Arquitectura de Variables y Datos

* **Inmutabilidad:** `BANK_CAP_USD` se define como `constant` y `MAX_WITHDRAWAL_PER_TX` como `immutable`, lo cual optimiza el gas ya que estos valores se almacenan en el bytecode o se fijan durante el despliegue.
* **Aritmética Segura:** La lógica de conversión de decimales en `_getUsdValueFromWei` implementa la regla de multiplicar antes de dividir para preservar la precisión al convertir de Wei ($10^{18}$ decimales) a USD ($10^{8}$ decimales).
* **Catálogo de Tokens:** La configuración de tokens ERC-20 se almacena en una `struct` dentro de un `mapping` (`s_tokenCatalog`), agrupando `priceFeedAddress` y `tokenDecimals`. Esta estructura mejora la eficiencia de lectura de almacenamiento (SLOAD).

---

## 4. Casos de Prueba (Módulo 3)

<details>
<summary><strong>🧪 Casos de Prueba Detallados (Módulo 3)</strong></summary>

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

