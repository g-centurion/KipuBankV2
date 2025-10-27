# KipuBankV2: Plataforma de Bóveda Descentralizada Multi-Token y Multi-Rol

**URL del Contrato Desplegado y verificado en Sepolia:**
* https://sepolia.etherscan.io/address/0x1a74a3A02a1868813Bd62D74F30A63efCA584912
* https://eth-sepolia.blockscout.com/address/0x1a74a3A02a1868813Bd62D74F30A63efCA584912?tab=contract
* https://testnet.routescan.io/address/0x1a74a3A02a1868813Bd62D74F30A63efCA584912/contract/11155111/code
* https://repo.sourcify.dev/11155111/0x1a74a3A02a1868813Bd62D74F30A63efCA584912

---

El proyecto KipuBankV2 representa la evolución a un contrato de producción a partir del contrato base KipuBank del Módulo 2. Este contrato simula una bóveda segura que gestiona depósitos en activos nativos (ETH) y tokens ERC-20, utilizando infraestructura descentralizada (Chainlink) para la validación de límites de valor.

El código actualizado del contrato se encuentra en la carpeta /src.

---

## 1) Mejoras de Arquitectura y Razones de Diseño

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

## 2) Decisiones de Diseño Importantes (Trade-offs)

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

## 3) Instrucciones de Despliegue e Interacción

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

## 4) Documento de Casos de Prueba: KipuBankV2

<details>
<summary>Ver Plan de Pruebas Completo</summary>

**Objetivo:** Verificar la implementación correcta de los patrones de seguridad (RBAC, Pausabilidad, CEI) y la lógica de negocio (Oráculos, Multi-token) según el estándar SCSVS V2 y los requisitos de V2.

### Configuración Inicial Asumida

| Parámetro | Valor | Razón/Fuente |
| :--- | :--- | :--- |
| **Rol/Cuenta A** | `0x0wner...` | Administrador/Dueño. Posee todos los roles administrativos (`DEFAULT_ADMIN_ROLE`, `PAUSE_MANAGER_ROLE`, etc.). |
| **Cuenta B** | `0xUser...` | Usuario Estándar. No tiene roles administrativos. |
| **MAX_WITHDRAWAL_PER_TX** | `1 ETH` (10^18 Wei) | Límite inmutable de retiro por transacción. |
| **BANK_CAP_USD** | `$1,000,000 USD` | Límite constante global del banco. |
| **Precio Oráculo ETH/USD** | `$2000 USD` | Se asume un precio fijo para el test (2000 * 10^8, ya que Chainlink usa 8 decimales). |
| **Token ERC-20** | `0xTokenA...` | Dirección de un token ERC-20 (Ej. USDC). |


### Fase 1: Verificación de Roles Administrativos (RBAC)
**Patrón Probado:** `AccessControl` y Principio de Mínimo Privilegio.

| ID | Explicación de la Prueba | Cuenta | Entrada/Función | Resultado Esperado |
| :--- | :--- | :--- | :--- | :--- |
| 1.1 | Verificar que el administrador puede cambiar la dirección del Oráculo (requiere `CAP_MANAGER_ROLE`). | A | `setEthPriceFeedAddress(0xNewAddr)` | Éxito. La variable `s_priceFeedAddress` se actualiza. |
| 1.2 | Verificar que un usuario estándar no puede realizar tareas administrativas. | B | `setEthPriceFeedAddress(0xNewAddr)` | REVERTIR con `Bank__Unauthorized()` (Implícita de `onlyRole`). |
| 1.3 | Verificar que el administrador puede dar soporte a un nuevo token (requiere `TOKEN_MANAGER_ROLE`). | A | `addSupportedToken(0xTokenA, 0xPriceFeed, 18)` | Éxito. Se emite `TokenSupported`. |
| 1.4 | Verificar que un usuario estándar no puede añadir un token. | B | `addSupportedToken(...)` | REVERTIR con `Bank__Unauthorized()`. |


### Fase 2: Pausabilidad y Mitigación de DoS
**Patrón Probado:** `Pausable` (herencia) y Prevención de Denegación de Servicio (DoS).

| ID | Explicación de la Prueba | Cuenta | Entrada/Función | Resultado Esperado |
| :--- | :--- | :--- | :--- | :--- |
| 2.1 | Verificar que el administrador puede pausar el contrato (requiere `PAUSE_MANAGER_ROLE`). | A | `pause()` | Éxito. El estado interno cambia a pausado. |
| 2.2 | Verificar que la función transaccional `deposit()` falla cuando está pausada. | B | `deposit()` (valor 0.1 ETH) | REVERTIR debido al modificador `whenNotPaused`. |
| 2.3 | Verificar que el administrador puede despausar el contrato. | A | `unpause()` | Éxito. El estado interno cambia a activo. |
| 2.4 | Verificar que `deposit()` funciona después de despausar. | B | `deposit()` (valor 0.1 ETH) | Éxito. Se emite `DepositSuccessful`. |


### Fase 3: Operaciones con ETH y Lógica de Oráculos
**Patrón Probado:** Conversión de valores (Multiplicar antes de dividir) y Lógica de límites de negocio (V8).

| ID | Explicación de la Prueba | Cuenta | Entrada/Función | Resultado Esperado |
| :--- | :--- | :--- | :--- | :--- |
| 3.1 | Depósito normal (sin alcanzar el límite). | B | `deposit()` (0.5 ETH) | Éxito. `balances[B][address(0)]` se incrementa en 0.5 ETH. |
| 3.2 | Límite Global USD (Fallo): Intentar exceder el límite de 1M USD. (Si 1 ETH = $2000, 500 ETH es el límite. Intentar depositar 501 ETH). | B | `deposit()` (501 ETH) | REVERTIR con el error `Bank__DepositExceedsCap` mostrando el límite en USD. |
| 3.3 | Límite de Retiro TX (Fallo): Intentar retirar más del límite inmutable (1 ETH). | B | `withdraw(1.1 ETH)` | REVERTIR con `Bank__WithdrawalExceedsLimit`. |
| 3.4 | Saldo Insuficiente (Fallo): Intentar retirar más de lo depositado (Saldo de B es 0.5 ETH). | B | `withdraw(0.6 ETH)` | REVERTIR con `Bank__InsufficientBalance`. |
| 3.5 | Retiro Exitoso (CEI): Retirar 0.2 ETH. | B | `withdraw(0.2 ETH)` | Éxito. Verificación clave: El saldo se actualiza (`balances[B]` es 0.3 ETH) *antes* de que ocurra la transferencia de `call`. |
| 3.6 | Verificar la Transferencia Segura. | B | Retiro exitoso anterior (3.5). | Éxito. Se debe usar la llamada de bajo nivel `call{value: amount}("")` en lugar de `transfer` o `send`. |


### Fase 4: Operaciones ERC-20 (Multi-Token)
**Patrón Probado:** `SafeERC20` para transferencias seguras y Mapeos Anidados para contabilidad multi-token.

| ID | Explicación de la Prueba | Cuenta | Entrada/Función | Resultado Esperado |
| :--- | :--- | :--- | :--- | :--- |
| 4.1 | Depósito de Token (Aprobación Requerida): Asumir que `0xTokenA` está soportado (ver 1.3). | B | Previo: B llama `TokenA.approve(KipuBankV2, 50 TKN)`. Luego: `depositToken(0xTokenA, 50 TKN)` | Éxito. El contrato utiliza `safeTransferFrom` para mover 50 TKN de B al KipuBankV2. `balances[B][0xTokenA]` se incrementa. |
| 4.2 | Depósito Fallido (Token No Soportado): Intentar depositar un token no registrado. | B | `depositToken(0xUnknownToken, 10 TKN)` | REVERTIR con `Bank__TokenNotSupported`. |
| 4.3 | Retiro de Token Exitoso: Retirar 10 TKN. | B | `withdrawToken(0xTokenA, 10 TKN)` | Éxito. El contrato utiliza `safeTransfer` para enviar 10 TKN a B. `balances[B][0xTokenA]` se reduce. |
| 4.4 | Retiro de Token (Fallo): Intentar retirar un token con saldo insuficiente. | B | `withdrawToken(0xTokenA, 100 TKN)` (Saldo restante 40 TKN) | REVERTIR con `Bank__InsufficientBalance`. |


Hemos cubierto la inicialización, la seguridad administrativa (RBAC y Pausabilidad), la lógica de negocio (Oráculos, Límites) y las interacciones con tokens (SafeERC20).

</details>

---

## 5) Diagramas de Arquitectura y Flujo

<details>
<summary>Ver Diagrama 1: Arquitectura General y Componentes</summary>

```mermaid
graph TD
    subgraph "Actores"
        Admin["Admin Dueno"]
        User["Usuario Estandar"]
    end

    subgraph "Contrato KipuBankV2"
        Core["Logica Principal KipuBankV2"]
        subgraph "Componentes Heredados OpenZeppelin"
            RBAC(AccessControl)
            Pause(Pausable)
            SafeLib(SafeERC20)
        end
        Balances["Balances mapping anidado"]
        Core --- RBAC
        Core --- Pause
        Core --- SafeLib
        Core --- Balances
    end

    subgraph "Dependencias Externas"
        Oracle["Chainlink Oracle ETH USD"]
        Token["Contrato ERC-20 Ej USDC"]
    end

    Admin -- "Gestiona RBAC" --> Core
    User -- "Interactua deposit withdraw" --> Core

    Core -- "Obtiene precio" --> Oracle
    Core -- "Transfiere safeTransfer From" --> Token
    User -- "Aprueba approve" --> Token
````

<details>
<summary>Ver Diagrama 2: Control de Acceso Basado en Roles (RBAC)</summary>

```mermaid
graph LR
    Admin("Deployer y Admin") -- "Posee" --> DEFAULT_ADMIN_ROLE

    subgraph "Roles de Gestion"
        DEFAULT_ADMIN_ROLE -- "Otorga Revoca" --> PAUSE_MANAGER_ROLE
        DEFAULT_ADMIN_ROLE -- "Otorga Revoca" --> CAP_MANAGER_ROLE
        DEFAULT_ADMIN_ROLE -- "Otorga Revoca" --> TOKEN_MANAGER_ROLE
    end

    subgraph "Funciones Protegidas"
        F1["pause o unpause"]
        F2["setEthPriceFeedAddress"]
        F3["addSupportedToken"]
    end

    PAUSE_MANAGER_ROLE -- "Ejecuta" --> F1
    CAP_MANAGER_ROLE -- "Ejecuta" --> F2
    TOKEN_MANAGER_ROLE -- "Ejecuta" --> F3
````

<details>
<summary>Ver Diagrama 3: Flujo de Deposito de ETH (Verificacion de Limite USD)</summary\>

```mermaid
sequenceDiagram
    actor User
    participant KipuBankV2
    participant Oracle as "Chainlink ETH USD"

    User->>KipuBankV2: "deposit() con 0.5 ETH"
    activate KipuBankV2
    KipuBankV2->>KipuBankV2: "1. Verificar whenNotPaused"
    KipuBankV2->>Oracle: "2. Obtener precio ETH"
    activate Oracle
    Oracle-->>KipuBankV2: "Retorna precio 2000"
    deactivate Oracle
    KipuBankV2->>KipuBankV2: "3. Calcular valor USD del deposito"
    KipuBankV2->>KipuBankV2: "4. Verificar Limite Global < BANK_CAP_USD"
    KipuBankV2->>KipuBankV2: "5. Effects Actualizar balances"
    KipuBankV2-->>User: "Exito Emite DepositSuccessful"
    deactivate KipuBankV2
````

<details>
<summary>Ver Diagrama 4: Flujo de Retiro de ETH (Patron Checks-Effects-Interactions)</summary\>

```mermaid
sequenceDiagram
    actor User
    participant KipuBankV2

    User->>KipuBankV2: "withdraw amount 0.2 ETH"
    activate KipuBankV2

    note over KipuBankV2: "Inicio Checks"
    KipuBankV2->>KipuBankV2: "1. Verificar whenNotPaused"
    KipuBankV2->>KipuBankV2: "2. Verificar amount <= MAX_TX"
    KipuBankV2->>KipuBankV2: "3. Verificar amount <= Saldo del Usuario"
    note over KipuBankV2: "Fin Checks"

    note over KipuBankV2: "Inicio Effects Patron CEI"
    KipuBankV2->>KipuBankV2: "4. Actualizar balances User -= amount"
    note over KipuBankV2: "Fin Effects"

    note over KipuBankV2: "Inicio Interactions"
    KipuBankV2->>User: "5. Enviar ETH via call"
    note over KipuBankV2: "Fin Interactions"

    KipuBankV2-->>User: "Exito"
    deactivate KipuBankV2
````

<details>
<summary>Ver Diagrama 5: Flujo de Deposito de Token ERC-20</summary\>

```mermaid
sequenceDiagram
    actor User
    participant Token as "Contrato ERC-20"
    participant KipuBankV2

    note over User, KipuBankV2: "Prerrequisito Aprobacion"
    User->>Token: "1. approve KipuBankV2 amount"
    activate Token
    Token-->>User: "Exito"
    deactivate Token

    note over User, KipuBankV2: "Flujo de Deposito"
    User->>KipuBankV2: "2. depositToken Token amount"
    activate KipuBankV2
    KipuBankV2->>KipuBankV2: "3. Verificar whenNotPaused"
    KipuBankV2->>KipuBankV2: "4. Verificar Token es soportado"
    KipuBankV2->>Token: "5. safeTransferFrom User KipuBankV2 amount"
    activate Token
    Token-->>KipuBankV2: "Transfiere tokens"
    deactivate Token
    KipuBankV2->>KipuBankV2: "6. Effects Actualizar balances"
    KipuBankV2-->>User: "Exito"
    deactivate KipuBankV2
````

<details>
<summary>Ver Diagrama 6: Flujo de Retiro de Token ERC-20 (Patron CEI)</summary\>

```mermaid
sequenceDiagram
    actor User
    participant KipuBankV2
    participant Token as "Contrato ERC-20"

    User->>KipuBankV2: "withdrawToken Token amount"
    activate KipuBankV2

    note over KipuBankV2: "Inicio Checks"
    KipuBankV2->>KipuBankV2: "1. Verificar whenNotPaused"
    KipuBankV2->>KipuBankV2: "2. Verificar amount <= Saldo Token Usuario"
    note over KipuBankV2: "Fin Checks"

    note over KipuBankV2: "Inicio Effects Patron CEI"
    KipuBankV2->>KipuBankV2: "3. Actualizar balances User Token -= amount"
    note over KipuBankV2: "Fin Effects"

    note over KipuBankV2: "Inicio Interactions"
    KipuBankV2->>Token: "4. safeTransfer User amount"
    activate Token
    Token-->>KipuBankV2: "Transfiere tokens a User"
    deactivate Token
    note over KipuBankV2: "Fin Interactions"

    KipuBankV2-->>User: "Exito"
    deactivate KipuBankV2
````

<details>
<summary>Ver Diagrama 7: Flujo de Pausa de Emergencia (Pausable)</summary\>

```mermaid
sequenceDiagram
    actor Admin as "Admin PAUSE_MANAGER_ROLE"
    actor User
    participant KipuBankV2

    Admin->>KipuBankV2: "1. pause()"
    activate KipuBankV2
    KipuBankV2-->>Admin: "Exito, contrato pausado"
    deactivate KipuBankV2

    User->>KipuBankV2: "2. deposit()"
    activate KipuBankV2
    KipuBankV2->>KipuBankV2: "3. Falla check: whenNotPaused"
    KipuBankV2-->>User: "REVERTIR Pausado"
    deactivate KipuBankV2

    Admin->>KipuBankV2: "4. unpause()"
    activate KipuBankV2
    KipuBankV2-->>Admin: "Exito, contrato reactivado"
    deactivate KipuBankV2

    User->>KipuBankV2: "5. deposit()"
    activate KipuBankV2
    KipuBankV2->>KipuBankV2: "6. Exito check: whenNotPaused"
    KipuBankV2-->>User: "Exito"
    deactivate KipuBankV2
````

<details>
<summary>Ver Diagrama 8: Flujo de Deposito Fallido (Excede Limite USD)</summary\>

```mermaid
sequenceDiagram
    actor User
    participant KipuBankV2
    participant Oracle as "Chainlink ETH USD"

    note over User, KipuBankV2: "Banco casi lleno. Limite 1M USD."
    User->>KipuBankV2: "deposit() con 501 ETH"
    activate KipuBankV2
    KipuBankV2->>KipuBankV2: "1. Verificar whenNotPaused"
    KipuBankV2->>Oracle: "2. Obtener precio ETH"
    activate Oracle
    Oracle-->>KipuBankV2: "Retorna precio 2000"
    deactivate Oracle
    KipuBankV2->>KipuBankV2: "3. Calcular valor USD 501x2000=1002000"
    KipuBankV2->>KipuBankV2: "4. Falla check: Limite Global < BANK_CAP_USD"
    KipuBankV2-->>User: "REVERTIR Bank__DepositExceedsCap"
    deactivate KipuBankV2
````

<details>
<summary>Ver Diagrama 9: Logica Interna de Calculo USD (getUsdValueFromWei)</summary\>

```mermaid
graph TD
    Start("Inicio _getUsdValueFromWei") --> GetPrice("Obtener precio ETH de Chainlink")
    GetPrice --> CheckStale("Verificar si el precio es valido o esta obsoleto")
    CheckStale -- "Precio Valido" --> Calculate("Calcular valor: ethAmount x ethPriceUsd")
    CheckStale -- "Precio No Valido" --> Revert1("REVERTIR Error de Oraculo")
    Calculate --> Adjust("Ajustar decimales: resultado division 10e18")
    Adjust --> End("Fin: Retornar valor en USD")
````

