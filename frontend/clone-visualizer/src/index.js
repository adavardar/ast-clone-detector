// src/index.js

import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';  // Import global styles
import App from './App';  // Import the main App component
import reportWebVitals from './reportWebVitals';  // Optional: Web performance monitoring

ReactDOM.render(
  <React.StrictMode>
    <App />  {/* Render the App component */}
  </React.StrictMode>,
  document.getElementById('root')  // Mount the app to the DOM
);

reportWebVitals();  // Optional: Report performance metrics
