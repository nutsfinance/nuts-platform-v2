import React, { Component } from 'react';
import Table from '@material-ui/core/Table';
import TableBody from '@material-ui/core/TableBody';
import TableCell from '@material-ui/core/TableCell';
import TableHead from '@material-ui/core/TableHead';
import TableRow from '@material-ui/core/TableRow';

class LendingListComponent extends Component {
    state = {issuances: {}};

    componentDidMount() {
        const { drizzle } = this.props;
        const web3 = drizzle.web3;
        const lendingInstrumentManager = drizzle.contracts.LendingInstrumentManager;
        const LendingInstrumentManagerWeb3 = new web3.eth.Contract(lendingInstrumentManager.abi, lendingInstrumentManager.address);
        const lending = drizzle.contracts.Lending;
        LendingInstrumentManagerWeb3.methods.getIssuanceAddresses().call().then(issuanceAddresses => {
            for (let issuanceAddress of issuanceAddresses) {
                let lendingWeb3 = new web3.eth.Contract(lending.abi, issuanceAddress);
                lendingWeb3.getPastEvents(
                    'allEvents',
                    {
                      fromBlock: 0,
                      toBlock: 'latest'
                    }
                  ).then(results => {
                      console.log(issuanceAddress);
                      console.log(results);                      
                      this.setState(prevState => {
                        let issuances = Object.assign({}, prevState.issuances);
                        issuances[issuanceAddress] = results;
                        return {issuances};
                      });
                  });
            }
        });
    }

    render() {
        console.log(this.state.issuances);
        return (
            <div>
                <h3>Issuance List</h3>
                <Table>
                    <TableHead>
                        <TableRow>
                            <TableCell>Address</TableCell>
                            <TableCell align="right">Event</TableCell>
                        </TableRow>
                    </TableHead>
                    <TableBody>
                    {Object.entries(this.state.issuances).map(issuance => (
                        <TableRow key={issuance[0]}>
                            <TableCell>{issuance[0]}</TableCell>
                            <TableCell align="right">{JSON.stringify(issuance[1].map(event => event.event))}</TableCell>
                        </TableRow>
                    ))}
                    </TableBody>
                </Table>
            </div>
        );
    }
}

export default LendingListComponent;