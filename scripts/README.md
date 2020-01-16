### Activate Instrument
```
truffle exec scripts/activate_instrument.js --instrument=lending|borrowing|spotswap --fsp=0xec652e6CEC1558227b406E68539e3d725cCDdC32 --instrument-termination-timestamp=-1 --instrument-override-timestamp=-1 --support-maker-whitelist=false --support-taker-whitelist=false --instrument-registry-address=0xC14f5D8eE243901dF224D98B949e5e89e64F2f04
```

### Create Issuance
#### Lending
```
truffle exec scripts/create_issuance.js --instrument=lending --instrument-manager-address=0xd4f270c6370D21BC8e0705d8CDfDCA3bF47f3b8a --collateral-token-address=0x21FfD2c8a56A76C31AC9819fE3BD6723b6F1C147 --lending-token-address=0x6efE1932A8B72767C5d5b9F15ED84268f0f91c83 --lending-amount=20000 --collateral-ratio=15000 --tenor-days=20 --interest-rate=10000
```
#### Borrowing
```
truffle exec scripts/create_issuance.js --instrument=borrowing --instrument-manager-address=0xd4f270c6370D21BC8e0705d8CDfDCA3bF47f3b8a --collateral-token-address=0x21FfD2c8a56A76C31AC9819fE3BD6723b6F1C147 --borrowing-token-address=0x6efE1932A8B72767C5d5b9F15ED84268f0f91c83 --borrowing-amount=20000 --collateral-ratio=15000 --tenor-days=20 --interest-rate=10000
```
#### SpotSwap
```
truffle exec scripts/create_issuance.js --instrument=spotswap --instrument-manager-address=0xd4f270c6370D21BC8e0705d8CDfDCA3bF47f3b8a --input-token-address=0x21FfD2c8a56A76C31AC9819fE3BD6723b6F1C147 --output-token-address=0x6efE1932A8B72767C5d5b9F15ED84268f0f91c83 --input-amount=20000 --output-amount=20000 --duration=20
```

### Engage Issuance
```
truffle exec scripts/engage_issuance.js --instrument-manager-address=0xd4f270c6370D21BC8e0705d8CDfDCA3bF47f3b8a --issuance-id=1 --buyer-parameters=abc
```

### Instrument Escrow Deposit
```
truffle exec scripts/instrument_escrow_deposit.js --instrument-escrow-address=0x499abAc6f23e8D0EA4E331FEaFDfa502604fB38c --token-address=0x6efE1932A8B72767C5d5b9F15ED84268f0f91c83 --amount=200000
```

### Instrument Escrow Withdraw
```
truffle exec scripts/instrument_escrow_withdral.js --instrument-escrow-address=0x499abAc6f23e8D0EA4E331FEaFDfa502604fB38c --token-address=0x6efE1932A8B72767C5d5b9F15ED84268f0f91c83 --amount=200000
```

### Issuance Escrow Deposit
```
truffle exec scripts/issuance_escrow_deposit.js --instrument-manager-address=0xd4f270c6370D21BC8e0705d8CDfDCA3bF47f3b8a --token-address=0x6efE1932A8B72767C5d5b9F15ED84268f0f91c83 --amount=200000 --issuance-id=1 --issuance-escrow-address=0xeEaba61F11dCbeebE0919fe86C5AA161fcbe4eB2
```

### Instrument Escrow Withdraw
```
truffle exec scripts/issuance_escrow_withdraw.js --instrument-manager-address=0xd4f270c6370D21BC8e0705d8CDfDCA3bF47f3b8a --token-address=0x6efE1932A8B72767C5d5b9F15ED84268f0f91c83 --amount=200000 --issuance-id=1 --issuance-escrow-address=0xeEaba61F11dCbeebE0919fe86C5AA161fcbe4eB2
```
