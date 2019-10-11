import React, { Component } from 'react';
import { Drizzle } from '@drizzle/store';
import { DrizzleContext } from '@drizzle/react-plugin';
import CssBaseline from '@material-ui/core/CssBaseline';

import drizzleOptions from './drizzleOptions';
import DemoComponent from './DemoComponent';

import './App.css';

const drizzle = new Drizzle(drizzleOptions);

class App extends Component {
  render() {
    return (
      <DrizzleContext.Provider drizzle={drizzle}>
        <CssBaseline />
        <DemoComponent />
      </DrizzleContext.Provider>
    );
  }
}

export default App;
