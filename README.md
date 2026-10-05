# xion-assets

This template should help get you started developing with Vue 3 in Vite.

## verUSD pricing reference

The verUSD entries in `public/chain-registry/xion/assetlist.json` (mainnet) and
`public/chain-registry/testnets/xiontestnet2/assetlist.json` (testnet) use
`coingecko_id: "stable-coin-2"`, the API ID for
[Stable Coin (SBC) on CoinGecko](https://www.coingecko.com/en/coins/stable-coin-2).

This temporary pricing policy was approved on 2026-10-05 based on the project
owner's confirmation that verUSD is created through Brale and based on SBC.
It uses SBC's market USD price as a reference for valuing verUSD holdings. It is
not a fixed $1 price or a direct verUSD market quote. The asset's denom, name,
symbol, and decimals continue to identify verUSD; this pricing reference does
not authorize using SBC branding for verUSD.

Once a dedicated verUSD CoinGecko listing is available, verify its API ID and
replace `stable-coin-2` in both verUSD entries with that ID. Update this policy
documentation at the same time.

## Recommended IDE Setup

[VSCode](https://code.visualstudio.com/) + [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar) (and disable Vetur).

## Type Support for `.vue` Imports in TS

TypeScript cannot handle type information for `.vue` imports by default, so we replace the `tsc` CLI with `vue-tsc` for type checking. In editors, we need [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar) to make the TypeScript language service aware of `.vue` types.

## Customize configuration

See [Vite Configuration Reference](https://vite.dev/config/).

## Project Setup

```sh
npm install
```

### Compile and Hot-Reload for Development

```sh
npm run dev
```

### Type-Check, Compile and Minify for Production

```sh
npm run build
```
