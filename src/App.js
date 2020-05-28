import React from 'react';
import logo from './logo.svg';
import './App.css';

function App() {
  let ip = process.env.REACT_APP_IP_ADDRESS 
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          ip = {ip }
        </p>
        <p>iiiiiiiiii!</p>
      </header>
    </div>
  );
}

export default App;
