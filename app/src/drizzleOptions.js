import InstrumentManager from './contracts/InstrumentV3Manager.json';
import InstrumentEscrow from './contracts/InstrumentEscrowInterface.json';
import SampleToken from './contracts/TokenMock.json';
import ParametersUtil from './contracts/ParametersUtil.json';
import Saving from './contracts/Saving.json';
import Lending from './contracts/Lending.json';
import Borrowing from './contracts/Borrowing.json';
import SpotSwap from './contracts/SpotSwap.json';

// Note: InstrumentManager and InstrumentEscrow are created in smart contract.
// So we need to hard code their address in corresponding networks here.

// Network 4 is Rinkeby
const SavingInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
SavingInstrumentManager["contractName"] = "SavingInstrumentManager";
SavingInstrumentManager["networks"]["4"] = {
  "address": "0xb4Da92363991ec58e21d03206485b3BdFb986559",
  "transactionHash": "0x4050e9a9b8e6fdacb29314cde8436f44666243111a0f6fc9cb924ed5aebe9825"
};
const SavingInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
SavingInstrumentEscrow["contractName"] = "SavingInstrumentEscrow";
SavingInstrumentEscrow["networks"]["4"] = {
  "address": "0x6b4D10F6b927c27998bC3aA4C05d8CdF2A1C9F6E",
  "transactionHash": "0x4050e9a9b8e6fdacb29314cde8436f44666243111a0f6fc9cb924ed5aebe9825"
};
Saving["networks"]["4"] = {
  "address": "0xe77FeD97BacCeCc2F58e9426063c28A250eA91a1",
  "transactionHash": "0xad1ffc08857c69d177d1e9b9af0f09f3977e92fe987daf9b39e198e0a079055f"
};


const LendingInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
LendingInstrumentManager["contractName"] = "LendingInstrumentManager";
LendingInstrumentManager["networks"]["4"] = {
  "address": "0xD2663B4BB426C4812f7878C1D9473914A020D2F9",
  "transactionHash": "0xe199c8b26ba6cc5dd5f7fd83c138178b0741ba57fc049eb159f55312af825f6e"
};
const LendingInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
LendingInstrumentEscrow["contractName"] = "LendingInstrumentEscrow";
LendingInstrumentEscrow["networks"]["4"] = {
  "address": "0xEBBd0d5F240BD1940ffe9Aa74E3965079829b4A0",
  "transactionHash": "0xe199c8b26ba6cc5dd5f7fd83c138178b0741ba57fc049eb159f55312af825f6e"
};
Lending["networks"]["4"] = {
  "address": "0x92A6206DCeD85216B7447c12144FD1f2F0D16528",
  "transactionHash": "0x0286a16ac6e05a1746a56c2fa5317bb7aab4d0e07728305b5703ac51b396c19d"
};


const BorrowingInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
BorrowingInstrumentManager["contractName"] = "BorrowingInstrumentManager";
BorrowingInstrumentManager["networks"]["4"] = {
  "address": "0x3dB76b526d03b305018f1547E33C604444287a05",
  "transactionHash": "0x95e4d2136495ce7740de44f974fc45dddb844b48dbb59c1d2f0173f17c1ee802"
};
const BorrowingInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
BorrowingInstrumentEscrow["contractName"] = "BorrowingInstrumentEscrow";
BorrowingInstrumentEscrow["networks"]["4"] = {
  "address": "0xe778ff61533363e88bAfF99Cb4dFa9772c9F9039",
  "transactionHash": "0x95e4d2136495ce7740de44f974fc45dddb844b48dbb59c1d2f0173f17c1ee802"
};
Borrowing["networks"]["4"] = {
  "address": "0x1993dde664C76075DE5706d272fC5AE35Dc508A9",
  "transactionHash": "0xd299b958e158fa0612def55a8ddaef06bf4d029a9573f91eae372295f9a86ee9"
};

const SpotSwapInstrumentManager = JSON.parse(JSON.stringify(InstrumentManager));
SpotSwapInstrumentManager["contractName"] = "SpotSwapInstrumentManager";
SpotSwapInstrumentManager["networks"]["4"] = {
  "address": "0xcc4036e2D281a170431D7FA024A555a5fbd5C9c3",
  "transactionHash": "0x337cb7e2b941a46d5a37a809af3a13d973143eae0aa4c252f1463d62f22615ee"
};
const SpotSwapInstrumentEscrow = JSON.parse(JSON.stringify(InstrumentEscrow));
SpotSwapInstrumentEscrow["contractName"] = "SpotSwapInstrumentEscrow";
SpotSwapInstrumentEscrow["networks"]["4"] = {
  "address": "0xFEC8B41C7094BE3eAC350099665cDB930467182F",
  "transactionHash": "0x337cb7e2b941a46d5a37a809af3a13d973143eae0aa4c252f1463d62f22615ee"
};
SpotSwap["networks"]["4"] = {
  "address": "0x0A9890FE23FB91aee615B8D3AB342fB348fff41e",
  "transactionHash": "0x380ca3bc4dce98839864a584fae02120962433d72b4aeb89eeb6f34b6f4b1df5"
};

const options = {
    web3: {
      block: false,
      fallback: {
        type: "ws",
        url: "ws://127.0.0.1:8545",
      },
    },
    contracts: [
      Saving,
      SavingInstrumentManager,
      SavingInstrumentEscrow,
      Lending,
      LendingInstrumentManager,
      LendingInstrumentEscrow,
      Borrowing,
      BorrowingInstrumentManager,
      BorrowingInstrumentEscrow,
      SpotSwap,
      SpotSwapInstrumentManager,
      SpotSwapInstrumentEscrow,
      SampleToken,
      ParametersUtil
    ],
    polls: {
      accounts: 1500,
    },
  };
  
  export default options;