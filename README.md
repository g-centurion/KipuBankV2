# KipuBankV2: Bóveda Multi-Token con Control de Acceso y Oráculos Chainlink

**URL del Contrato Desplegado en Sepolia:** [https://sepolia.etherscan.io/address/0x70A910C10fAE01802f1aB9798773275B67aE5710]

---

## 1. Explicación a Alto Nivel de las Mejoras

`KipuBankV2` es la refactorización del contrato `KipuBank` original, evolucionando su arquitectura para cumplir con estándares de producción en términos de seguridad, control de acceso y escalabilidad.

Las mejoras clave del Módulo 3 son:

| Componente | Descripción de la Mejora |
| :--- | :--- |
| **Control de Acceso (Roles)** | Implementación de `AccessControl` de OpenZeppelin para delegar permisos de forma granular, incluyendo `CAP_MANAGER_ROLE`, `TOKEN_MANAGER_ROLE`, y `PAUSE_MANAGER_ROLE`. |
| **Oráculos de Chainlink** | Integración de Chainlink Data Feeds para convertir el valor de ETH a USD, permitiendo que el límite global (`BANK_CAP_USD`) se aplique en dólares, y no en unidades de ETH volátiles. | 
| **Soporte Multi-token** | El contrato ahora soporta depósitos y retiros de tokens ERC-20, utilizando un catálogo administrado (`s_tokenCatalog`) y mappings anidados (`balances`) para llevar la contabilidad por token. | 
| **Seguridad de Emergencia** | Herencia del contrato `Pausable` de OpenZeppelin, gestionado por el `PAUSE_MANAGER_ROLE`, para detener las funciones críticas (`deposit`, `withdraw`) ante amenazas de seguridad o fallos de oráculo. | atrón de Seguridad. |

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

## 4. Casos de Prueba y API del Contrato

<details>
<summary><strong>🧪 Casos de Prueba Detallados (Módulo 3)</strong></summary>

### Configuración de Pruebas

* **Contrato:** `KipuBankV2.sol`
* **Red de Prueba:** Sepolia Testnet
* **Versión de Solidity:** `^0.8.26`
* **Cuentas de Prueba:**
    * **ADMIN (Desplegador):** (Tu cuenta MetaMask). Posee `DEFAULT_ADMIN_ROLE`, `CAP_MANAGER_ROLE`, `TOKEN_MANAGER_ROLE`, y `PAUSE_MANAGER_ROLE`.
    * **USUARIO B:** Otra cuenta con Sepolia ETH para actuar como usuario estándar.
* **Parámetros de Despliegue Asumidos:**
    * **Oráculo ETH/USD (Sepolia):** `0x694AA1769357215Ef4bE215cd2aa0325eEba1cda`
    * **MAX_WITHDRAWAL_PER_TX:** `1000000000000000000` (1 ETH en Wei)
    * **BANK_CAP_USD:** `1000000000000000000000000` ($1M USD con $10^8$ decimales)

<br>

<details>
<summary><strong>FASE 1: Verificación de Variables y Oráculos (Lectura)</strong></summary>

| ID | Requisito a Probar | Función/Variable | Entrada | Resultado Esperado | Verificación |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1.1 | Variable `constant` | `BANK_CAP_USD` (view) | N/A | Debe mostrar `1000000000000000000000000` (valor fijo de $1M). | Confirma el uso de `constant`. |
| 1.2 | Variable `immutable` | `MAX_WITHDRAWAL_PER_TX` (view) | N/A | Debe mostrar `1000000000000000000` (1 ETH en Wei). | Confirma el uso de `immutable`. |
| 1.3 | Instancia de Oráculo | `getEthPriceInUsd()` (view) | N/A | Debe retornar un número grande (ej., 3000 * $10^8$). | Confirma la conexión con el Data Feed de Chainlink. |

</details>

<details>
<summary><strong>FASE 2: Control de Acceso y Pausabilidad (PAUSE_MANAGER_ROLE)</strong></summary>
<p>Este test verifica el "interruptor de emergencia" (Fail-Safe). Se debe usar la cuenta ADMIN.</p>

| ID | Paso | Función/Acción | Entrada | Resultado Esperado | Verificación |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2.1 | Activar Pausa | `pause()` | N/A | Transacción Exitosa. | El estado `paused` es ahora `true`. Confirma que `PAUSE_MANAGER_ROLE` funciona. |
| 2.2 | Prueba de Bloqueo | `deposit()` | Valor: 0.01 ETH | Transacción debe REVERTIR. | Revert: El error debe indicar que la función falló debido a la pausa (Error de `Pausable`/`whenNotPaused`). |
| 2.3 | Desactivar Pausa | `unpause()` | N/A | Transacción Exitosa. | El estado `paused` es ahora `false`. |
| 2.4 | Prueba de Continuidad | `deposit()` | Valor: 0.01 ETH | Transacción Exitosa. | El depósito funciona, confirmando que la seguridad fue restaurada. |

</details>

<details>
<summary><strong>FASE 3: Soporte Multi-token (TOKEN_MANAGER_ROLE)</strong></summary>
<p>Este test valida la creación y el uso del Catálogo Multi-token (<code>s_tokenCatalog</code>).</p>

| ID | Paso | Función | Parámetros (Inputs) | Resultado Esperado | Verificación |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 3.1 | Registrar Token (ADMIN) | `addSupportedToken` | `tokenAddress`: `0x111...111` (Mock Token) <br> `priceFeedAddress`: `0x1486940d5E31A21e25e22C66e92751505A4b23b8` (DAI/USD Sepolia) <br> `decimals`: 18 | Transacción Exitosa. | Log: Buscar el evento `TokenSupported` con los datos del token. |
| 3.2 | Intento de Duplicado (ADMIN) | `addSupportedToken` | Mismos parámetros que 3.1. | Transacción debe REVERTIR. | Revert: Error de `require` (ej., "Bank: Token already supported") verificando la unicidad del catálogo. |
| 3.3 | Retiro No Soportado (USUARIO B) | `withdrawToken` | `tokenAddress`: `0x222...222` (Dirección no registrada) <br> `amount`: 1 | Transacción debe REVERTIR. | Revert: Error personalizado `Bank__TokenNotSupported`, confirmando que el check del catálogo funciona. |

</details>

<details>
<summary><strong>FASE 4: Depósito ETH y Comprobación de Límite Global (CAP CHECK)</strong></summary>
<p>Este test valida la Función de conversión de decimales y valores contra el <code>BANK_CAP_USD</code>.</p>

| ID | Paso | Función | Entrada (Value) | Resultado Esperado | Verificación |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 4.1 | Depósito Exitoso (USUARIO B) | `deposit()` | 0.1 ether | Transacción Exitosa. | Lectura: El saldo de `balances[Usuario B][address(0)]` es 0.1 ETH (Mapeo anidado). |
| 4.2 | Exceso de Límite (USUARIO B) | `deposit()` | Ingresar un valor que, sumado al balance actual del contrato, exceda $1M USD (el valor exacto depende del precio ETH/USD en Sepolia, generalmente requiere un gran valor, como 5000 ether). | Transacción debe REVERTIR. | Revert: Error personalizado `Bank__DepositExceedsCap`. Confirma que el oráculo y la conversión $10^{18}$ → $10^{8}$ funcionan. |

</details>

<details>
<summary><strong>FASE 5: Retiro ERC-20 (CEI y Límite Inmutable)</strong></summary>
<p>Este test valida el cumplimiento del patrón Checks-Effects-Interactions (CEI) y el límite immutable. Asumimos que el USUARIO A tiene un saldo del token Mock (<code>0x111...111</code>) > 1 ETH, posiblemente cargado directamente para la prueba.</p>

| ID | Paso | Función | Parámetros (Inputs) | Resultado Esperado | Verificación |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 5.1 | Exceder Límite TX (USUARIO A) | `withdrawToken` | `tokenAddress`: `0x111...111` <br> `amount`: `2000000000000000000` (2 ETH) | Transacción debe REVERTIR. | Revert: Error `Bank__WithdrawalExceedsLimit`, confirmando la variable immutable. |
| 5.2 | Retiro Seguro (USUARIO A) | `withdrawToken` | `tokenAddress`: `0x111...111` <br> `amount`: `500000000000000000` (0.5 ETH) | Transacción Exitosa. | Inspección de Lógica (CEI): El saldo del usuario en el mapeo anidado (`balances`) debe disminuir antes de que se ejecute la llamada externa `safeTransfer`. |

</details>






