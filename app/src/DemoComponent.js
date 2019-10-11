import React, { Component } from "react";
import { newContextComponents } from '@drizzle/react-components';
import { DrizzleContext } from '@drizzle/react-plugin';
import Card from '@material-ui/core/Card';
import CardContent from '@material-ui/core/CardContent';
import Grid from '@material-ui/core/Grid';

const { AccountData, ContractData, ContractForm } = newContextComponents;

export default class DemoComponent extends Component {
    state = {
        depositValue: 0,
        collateralTokenAddress: '',
        lendinglTokenAddress: '',
        lendinglAmount: 0,
        collateralRatio: 0,
        engagementDueDays: 0,
        tenorDays: 0,
        interestRate: 0,
    };

    handleDepositValueChange = (event) => {
        this.setState({depositValue: event.target.value});
    }

    handleIssuanceParameterChange = (event) => {
        this.setState({ [event.target.name]: event.target.value });
    }

    renderDemo = (drizzle, drizzleState) => {
        const { accounts } = drizzleState;
        return (
            <Grid container spacing={3} className="App">
                <Grid item xs={6}>
                    <Card className="Card">
                        <CardContent>
                            <h2>Account Balance</h2>
                            <AccountData drizzle={drizzle} drizzleState={drizzleState}
                                accountIndex={0} units="ether" precision={3} render={({ address, balance, units }) => (
                                    <div>
                                        <div>ETH: <span style={{ color: "red" }}>{balance}</span></div>
                                    </div>
                                    )}
                            />

                            <span>Sample Token: </span>
                            <span style={{ color: "red" }}><ContractData drizzle={drizzle} drizzleState={drizzleState}
                                contract="TokenMock" method="balanceOf" methodArgs={[accounts[0]]}/></span>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={6}>
                    <Card className="Card">
                        <CardContent>
                            <h2>Escrow Balance</h2>
                            <span>ETH: </span>
                            <span style={{ color: "red" }}><ContractData drizzle={drizzle} drizzleState={drizzleState}
                                contract="InstrumentEscrowInterface" method="getBalance" methodArgs={[accounts[0]]}/></span>
                            <br/>
                            <span>Sample Token: </span>
                            <span style={{ color: "red" }}><ContractData drizzle={drizzle} drizzleState={drizzleState}
                                contract="InstrumentEscrowInterface" method="getTokenBalance" methodArgs={[accounts[0], drizzle.contracts.TokenMock.address]}/></span>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={6}>
                    <Card className="Card">
                        <CardContent>
                            <h3>Deposit ETH</h3>
                            <input type="number" placeholder='Amount in Wei' onChange={this.handleDepositValueChange}/>
                            <div style={{ display: "inline-block" }}>
                                <ContractForm drizzle={drizzle} drizzleState={drizzleState}
                                    contract="InstrumentEscrowInterface"
                                    method="deposit"
                                    sendArgs={{ value: this.state.depositValue }}
                                    />
                            </div>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={6}>
                    <Card className="Card">
                        <CardContent>
                            <h3>Withdraw ETH</h3>
                            <ContractForm drizzle={drizzle} drizzleState={drizzleState}
                                contract="InstrumentEscrowInterface"
                                method="withdraw"
                                labels={['Amount in Wei']}
                                />
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={6}>
                    <Card className="Card">
                        <CardContent>
                            <h3>Deposit Sample Token</h3>
                            <ContractForm drizzle={drizzle} drizzleState={drizzleState}
                                contract="TokenMock"
                                method="approve"
                                render={({ inputs, inputTypes, state, handleInputChange, handleSubmit }) => (
                                    <form onSubmit={handleSubmit}>
                                        <input
                                          key='value'
                                          type='number'
                                          name='value'
                                          value={state['value']}
                                          placeholder='Amount'
                                          onChange={handleInputChange}
                                        />

                                        <button
                                            key="submit"
                                            type="button"
                                            onClick={e => {state['spender'] = drizzle.contracts.InstrumentEscrowInterface.address; handleSubmit(e)}}
                                        >
                                            Approve
                                        </button>
                                    </form>
                    
                                  )}
                                />
                            <ContractForm drizzle={drizzle} drizzleState={drizzleState}
                                contract="InstrumentEscrowInterface"
                                method="depositToken"
                                render={({ inputs, inputTypes, state, handleInputChange, handleSubmit }) => (
                                    <form onSubmit={handleSubmit}>
                                        <input
                                          key='amount'
                                          type='number'
                                          name='amount'
                                          value={state['amount']}
                                          placeholder='Amount'
                                          onChange={handleInputChange}
                                        />

                                        <button
                                            key="submit"
                                            type="button"
                                            onClick={e => {state['token'] = drizzle.contracts.TokenMock.address; handleSubmit(e)}}
                                        >
                                            Deposit
                                        </button>
                                    </form>
                    
                                  )}
                                />
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={6}>
                    <Card className="Card">
                        <CardContent>
                            <h3>Withdraw Sample Token</h3>
                            <ContractForm drizzle={drizzle} drizzleState={drizzleState}
                                contract="InstrumentEscrowInterface"
                                method="withdrawToken"
                                render={({ inputs, inputTypes, state, handleInputChange, handleSubmit }) => (
                                    <form onSubmit={handleSubmit}>
                                        <input
                                          key='amount'
                                          type='number'
                                          name='amount'
                                          value={state['amount']}
                                          placeholder='Amount'
                                          onChange={handleInputChange}
                                        />

                                        <button
                                            key="submit"
                                            type="button"
                                            onClick={e => {state['token'] = drizzle.contracts.TokenMock.address; handleSubmit(e)}}
                                        >
                                            Withdraw
                                        </button>
                                    </form>
                    
                                  )}
                                />
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={12}>
                    <Card className="LongCard">
                        <CardContent>
                            <h3>Create New Lending Issuance</h3>
                            <form>
                                <input key='collateralTokenAddress'
                                    type='text'
                                    name='collateralTokenAddress'
                                    placeholder='Collateral Token Address'
                                    onChange={this.handleIssuanceParameterChange}
                                />
                                <input key='lendinglTokenAddress'
                                    type='text'
                                    name='lendinglTokenAddress'
                                    placeholder='Lending Token Address'
                                    onChange={this.handleIssuanceParameterChange}
                                />
                                <input key='lendinglAmount'
                                    type='number'
                                    name='lendinglAmount'
                                    placeholder='Lending Amount'
                                    onChange={this.handleIssuanceParameterChange}
                                />
                                <input key='collateralRatio'
                                    type='number'
                                    name='collateralRatio'
                                    placeholder='Collateral Ratio'
                                    onChange={this.handleIssuanceParameterChange}
                                />
                                <br/>
                                <input key='engagementDueDays'
                                    type='number'
                                    name='engagementDueDays'
                                    placeholder='Engagement Due Days'
                                    onChange={this.handleIssuanceParameterChange}
                                />
                                <input key='tenorDays'
                                    type='number'
                                    name='tenorDays'
                                    placeholder='Tenor Days'
                                    onChange={this.handleIssuanceParameterChange}
                                />
                                <input key='interestRate'
                                    type='number'
                                    name='interestRate'
                                    placeholder='Interest Rate'
                                    onChange={this.handleIssuanceParameterChange}
                                />
                            </form>
                            <span>Lending Issuance Parameters: </span>
                            <ContractData drizzle={drizzle} drizzleState={drizzleState}
                                contract="ParametersUtil" method="getLendingMakerParameters" 
                                methodArgs={[this.state.collateralTokenAddress, this.state.lendinglTokenAddress,
                                    this.state.lendinglAmount, this.state.collateralRatio, this.state.engagementDueDays,
                                    this.state.tenorDays, this.state.interestRate]}/>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>
        );
    };

    render() {
        return (
            <DrizzleContext.Consumer>
                {drizzleContext => {
                    const { drizzle, drizzleState, initialized } = drizzleContext;
                    if (!initialized) {
                        return "It's Loading...";
                    }

                    return this.renderDemo(drizzle, drizzleState);
                    
                }}
            </DrizzleContext.Consumer>
        );
    }
}