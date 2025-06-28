# SimpleSwap

> *El AMM sencillo que hace magia con tus tokens, sin vueltas ni complicaciones.*

---

## Descripción

**SimpleSwap** es un contrato inteligente básico para intercambios automáticos de tokens (AMM) y gestión de liquidez estilo Uniswap, pero sin tanto ruido. Permite a los usuarios:

- Añadir y remover liquidez de un par de tokens ERC-20.
- Realizar swaps directos entre dos tokens.
- Emitir y quemar tokens de proveedor de liquidez (LP tokens) para representar participación.
- Consultar precios y cantidades esperadas de salida con comisiones incluidas.

Está pensado para desarrolladores y entusiastas que quieran un AMM funcional, claro y ligero.

---

## Características principales

- **Soporte para pares de tokens ERC-20:** tokenA y tokenB configurados en la construcción.
- **Gestión de liquidez:** agrega/remueve liquidez con slippage mínimo controlado.
- **Swap con tarifa:** 0.3% de fee aplicado en los intercambios.
- **Tokens LP:** mint y burn para representar tu share del pool.
- **Fórmulas matemáticas básicas:** usando la raíz cuadrada para calcular la liquidez.

---

## Interfaz principal

### Funciones clave

- `addLiquidity(...)`  
  Añade liquidez al pool, mint LP tokens proporcionales.

- `removeLiquidity(...)`  
  Remueve liquidez, quema LP tokens y devuelve tokens proporcionales.

- `swapExactTokensForTokens(...)`  
  Intercambia un monto exacto de tokens de entrada por al menos una cantidad mínima de tokens de salida.

- `getPrice(base, quote)`  
  Devuelve el precio actual de un token base respecto a otro (escalado por 1e18).

- `getAmountOut(tokenIn, tokenOut, amountIn)`  
  Calcula la cantidad de tokens que recibirás al hacer un swap, considerando la comisión.

---

## Eventos

- `LiquidityAdded(provider, amountA, amountB, liquidity)`  
  Se emite al agregar liquidez.

- `LiquidityRemoved(provider, amountA, amountB, liquidity)`  
  Se emite al remover liquidez.

---

## Uso básico

1. Desplegar el contrato proporcionando las direcciones de los tokens y del contrato LP token.
2. Usar `addLiquidity` para depositar tokens y recibir LP tokens.
3. Realizar swaps usando `swapExactTokensForTokens`.
4. Retirar liquidez con `removeLiquidity`.

---

## Consideraciones

- El contrato asume que el token LP externo cumple con las funciones `mint` y `burn`.
- Las operaciones usan timestamps para evitar ejecuciones fuera de plazo (`deadline`).
- El slippage es controlado con valores mínimos aceptables para cada token.
- Solo swaps directos entre tokenA y tokenB están soportados (no rutas múltiples).

---




