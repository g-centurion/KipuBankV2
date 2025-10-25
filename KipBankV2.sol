// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

// =========================================================================
// M3: IMPORTACIONES DE LIBRERÍAS DE OPENZEPPELIN Y CHAINLINK
// =========================================================================

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; 
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol"; // Control de Acceso [5]
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";     // Pausabilidad [5]
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";       // Soporte Multi-token
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // Transferencias seguras [6]

// =========================================================================
// DOCUMENTACIÓN NATSENEC DEL CONTRATO
// =========================================================================

/// @title KipuBankV2
/// @author g-centurion
/// @notice Contrato de bóveda Multi-token y Multi-rol que usa Data Feeds de Chainlink para asegurar un límite global en USD.
contract KipuBankV2 is AccessControl, Pausable { 
    using SafeERC20 for IERC20; // Habilita safeTransfer y safeTransferFrom [6]

// ===============================================================
// CUSTOM ERRORS (M2/M3 Requisito)
// ===============================================================

    error Bank__DepositExceedsCap(uint256 currentBalanceUSD, uint256 bankCapUSD, uint256 attemptedDepositUSD);
    error Bank__WithdrawalExceedsLimit(uint256 limit, uint256 requested);
    error Bank__InsufficientBalance(uint256 available, uint256 requested);
    error Bank__TransferFailed();
    error Bank__Unauthorized();
    error Bank__TokenNotSupported();
    error Bank__InvalidTokenAddress();

// ===================================
// EVENTS (M2/M3 Requisito)
// ===================================

    event DepositSuccessful(address indexed user, uint256 amount);
    event WithdrawalSuccessful(address indexed user, uint256 amount);
    event TokenSupported(address indexed token, address priceFeed, uint8 decimals); 

// =========================================================================
// ROLES Y VARIABLES DE ESTADO (M3 Requisitos)
// =========================================================================

    // Roles personalizados (Access Control) [7]
    bytes32 public constant CAP_MANAGER_ROLE = keccak256("CAP_MANAGER_ROLE");
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE"); 
    bytes32 public constant PAUSE_MANAGER_ROLE = keccak256("PAUSE_MANAGER_ROLE"); 
    
    // CAPACIDAD Y LÍMITES
    /// Requisito: Variable Constant [8, 9]
    uint256 public constant BANK_CAP_USD = 1_000_000 * 10**8; 

    /// Requisito: Variable Immutable [10, 11]
    uint256 public immutable MAX_WITHDRAWAL_PER_TX;          

    // ORÁCULOS
    address private s_priceFeedAddress;

    // ESTRUCTURAS Y CATÁLOGO DE TOKENS (Soporte Multi-token) [5]
    struct TokenData {
        address priceFeedAddress;
        uint8 tokenDecimals;      
        bool isAllowed;           
    }
    // Mapeo de la dirección del token -> Datos de configuración.
    mapping(address => TokenData) private s_tokenCatalog; 

    // CONTABILIDAD MULTI-TOKEN
    /// Requisito: Mappings anidados [5, 12]
    mapping(address => mapping(address => uint256)) public balances;

    uint256 private _depositCount = 0;
    uint256 private _withdrawalCount = 0;

// ============================
// CONSTRUCTOR Y FUNCIONES ADMINISTRATIVAS
// =========================================================================

    constructor(address priceFeedAddress, uint256 maxWithdrawalAmount) {
        // Asignación de Roles al desplegador [7]
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CAP_MANAGER_ROLE, msg.sender);
        _grantRole(TOKEN_MANAGER_ROLE, msg.sender);
        _grantRole(PAUSE_MANAGER_ROLE, msg.sender); 

        // Inicialización de inmutables y mutables
        s_priceFeedAddress = priceFeedAddress;
        MAX_WITHDRAWAL_PER_TX = maxWithdrawalAmount;
    }
    
    // --- Funciones de Administración ---

    function pause() external onlyRole(PAUSE_MANAGER_ROLE) {
        _pause(); // Heredado de Pausable
    }

    function unpause() external onlyRole(PAUSE_MANAGER_ROLE) {
        _unpause(); // Heredado de Pausable
    }

    function setEthPriceFeedAddress(address newAddress) 
        external 
        onlyRole(CAP_MANAGER_ROLE) 
    {
        s_priceFeedAddress = newAddress;
    }

    function addSupportedToken(
        address tokenAddress, 
        address priceFeedAddress, 
        uint8 decimals
    ) 
        external 
        onlyRole(TOKEN_MANAGER_ROLE) 
    {
        require(tokenAddress != address(0), "Bank: Invalid token address"); 
        require(s_tokenCatalog[tokenAddress].isAllowed == false, "Bank: Token already supported");

        s_tokenCatalog[tokenAddress] = TokenData({
            priceFeedAddress: priceFeedAddress,
            tokenDecimals: decimals,
            isAllowed: true
        });

        emit TokenSupported(tokenAddress, priceFeedAddress, decimals);
    }

// =============================
// FUNCIONES EXTERNAS Y PÚBLICAS (Transaccionales)
// =========================================================================

/// @dev Permite a los usuarios depositar ETH (token nativo).
function deposit() external payable whenNotPaused { // Protegida por Pausable
    address ETH_TOKEN = address(0); // address(0) para Ether [5]

    // A. CHECKS (CEI Pattern, Oráculo y Límite Global en USD)
    uint256 ethPriceUsd = getEthPriceInUsd(); // Oráculos de Datos [5]
    uint256 currentContractBalance = address(this).balance;
    uint256 currentEthBalanceBeforeDeposit = currentContractBalance - msg.value;
    
    // Conversión de Decimales: Convertir el balance total a USD (8 decimales) [13]
    uint256 totalUsdValueIfAccepted = _getUsdValueFromWei(currentContractBalance, ethPriceUsd);
    
    if (totalUsdValueIfAccepted > BANK_CAP_USD) { 
        uint256 attemptedDepositUsd = _getUsdValueFromWei(msg.value, ethPriceUsd);
        uint256 currentUsdBalance = _getUsdValueFromWei(currentEthBalanceBeforeDeposit, ethPriceUsd);
        revert Bank__DepositExceedsCap(currentUsdBalance, BANK_CAP_USD, attemptedDepositUsd);
    }

    // B. EFFECTS 
    unchecked { // Optimización segura después del chequeo [14]
        balances[msg.sender][ETH_TOKEN] += msg.value; // Mapeo anidado [5]
    }
    _depositCount++;

    // C. INTERACTIONS (Emisión de evento) [15, 16]
    emit DepositSuccessful(msg.sender, msg.value);
}

/// @dev Permite a los usuarios retirar ETH.
function withdraw(uint256 amountToWithdraw) external whenNotPaused { 
    address ETH_TOKEN = address(0); 
    
    // A. CHECKS (CEI Pattern)
    uint256 userBalance = balances[msg.sender][ETH_TOKEN]; // Lectura de almacenamiento cacheada [17]
    uint256 limit = MAX_WITHDRAWAL_PER_TX; 
    
    if (amountToWithdraw > limit) {
        revert Bank__WithdrawalExceedsLimit(limit, amountToWithdraw);
    }

    if (userBalance < amountToWithdraw) {
        revert Bank__InsufficientBalance(userBalance, amountToWithdraw);
    }

    // B. EFFECTS (Actualización de estado antes de la llamada externa)
    unchecked {
        balances[msg.sender][ETH_TOKEN] = userBalance - amountToWithdraw;
    }
    _withdrawalCount++;

    // C. INTERACTIONS (Transferencia Segura) [18]
    (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}(""); // Uso de call [19, 20]

    if (!success) {
        revert Bank__TransferFailed();
    }

    emit WithdrawalSuccessful(msg.sender, amountToWithdraw);
}

/// @dev Permite a los usuarios depositar un token ERC-20 permitido.
function depositToken(address tokenAddress, uint256 amount) 
    external 
    whenNotPaused 
{
    // A. CHECKS
    require(tokenAddress != address(0), "Bank: Use deposit() for ETH"); 
    require(amount > 0, "Bank: Deposit amount must be positive");

    TokenData memory tokenData = s_tokenCatalog[tokenAddress];
    if (!tokenData.isAllowed) {
        revert Bank__TokenNotSupported(); 
    }
    
    // B. EFFECTS
    unchecked {
        balances[msg.sender][tokenAddress] += amount; // Uso del mapeo anidado [5]
    }

    // C. INTERACTIONS (Uso de SafeERC20.safeTransferFrom)
    // Esto transfiere los tokens si el usuario ha llamado a approve() previamente.
    IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount); 

    emit DepositSuccessful(msg.sender, amount); 
}

/// @dev Permite a los usuarios retirar un token ERC-20 permitido.
function withdrawToken(address tokenAddress, uint256 amount) 
    external 
    whenNotPaused 
{
    // A. CHECKS (CEI Pattern)
    TokenData memory tokenData = s_tokenCatalog[tokenAddress];
    require(tokenAddress != address(0), "Bank: Use withdraw() for ETH");
    require(tokenData.isAllowed, "Bank: Token is not supported for withdrawal");
    require(amount > 0, "Bank: Withdrawal amount must be positive");

    uint256 userBalance = balances[msg.sender][tokenAddress]; 
    uint256 limit = MAX_WITHDRAWAL_PER_TX; // Immutable limit
    
    if (amount > limit) {
        revert Bank__WithdrawalExceedsLimit(limit, amount);
    }
    
    if (userBalance < amount) {
        revert Bank__InsufficientBalance(userBalance, amount);
    }
    
    // B. EFFECTS 
    unchecked {
        balances[msg.sender][tokenAddress] = userBalance - amount;
    }
    _withdrawalCount++; 

    // C. INTERACTIONS (Transferencia Segura)
    IERC20(tokenAddress).safeTransfer(msg.sender, amount); // Uso de SafeERC20 [6]

    emit WithdrawalSuccessful(msg.sender, amount);
}

// ==============================
// FUNCIONES INTERNAS Y DE VISTA (M3 Requisitos: Oráculo y Conversión)
// =========================================================================

/// @dev Conversión de decimales: Convierte Wei (18 dec) a USD (8 dec).
function _getUsdValueFromWei(uint256 ethAmount, uint256 ethPriceUsd) 
    internal pure returns (uint256) 
{
    // Multiplicar antes de dividir para evitar la pérdida de precisión [13]
    return (ethAmount * ethPriceUsd) / 10**18;
}

/// @dev Llama al oráculo de Chainlink.
function getEthPriceInUsd() public view returns (uint256) {
    AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeedAddress);

    (
        /* uint80 roundID */,
        int256 price, 
        /* uint startedAt */,
        /* uint timeStamp */,
        /* uint80 answeredInRound */
    ) = priceFeed.latestRoundData(); // Data Feeds de Chainlink [5]

    if (price <= 0) {
        revert(); 
    }

    return uint256(price); 
}

// Funciones de vista (M2 Requisitos)
function getDepositCount() external view returns (uint256) {
    return _depositCount;
}

function getWithdrawalCount() external view returns (uint256) {
    return _withdrawalCount;
}

/// Requisito: Función privada [21]
function _getInternalBalance(address user) private view returns (uint256) {
    return balances[user][address(0)];
}
}
