# xion-assets

This template should help get you started developing with Vue 3 in Vite.

## verUSD pricing reference

The verUSD entries in `public/chain-registry/xion/assetlist.json` (mainnet) and
`public/chain-registry/testnets/xiontestnet2/assetlist.json` (testnet) use
`coingecko_id: "stable-coin-2"`, the API ID for
[Stable Coin (SBC) on CoinGecko](https://www.coingecko.com/en/coins/stable-coin-2).
The Keplr mainnet config (`public/keplr/cosmos/xion-mainnet.json`) uses the same
ID as `coinGeckoId`.

This is a temporary pricing reference, approved on 2026-10-05 because verUSD is
created through Brale and based on SBC. It values verUSD at SBC's market USD
price; it is not a fixed $1 price or a verUSD market quote. verUSD keeps its own
denom, name, symbol, decimals and logo; the reference does not license SBC
branding for verUSD.

Once verUSD has its own CoinGecko listing, verify its API ID and replace
`stable-coin-2` in these files (and in the upstream `cosmos/chain-registry` and
`chainapsis/keplr-chain-registry` entries), then update this section.

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
