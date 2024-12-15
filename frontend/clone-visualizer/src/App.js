// src/App.js

import React, { useState, useEffect } from 'react';
import TreeMap from './components/TreeMap';  // Import TreeMap component
import data from './data/cloning_data.json';  // Import the clone detection data from the JSON file

const App = () => {
  const [cloneData, setCloneData] = useState(null);  // State to store the clone data

  // useEffect to simulate loading of data when the component mounts
  useEffect(() => {
    setCloneData(data['Type-1']);  // Set Type-1 clone data to be used by TreeMap
  }, []);

  return (
    <div>
      <header>
        <h1>Code Clone Detection Visualization</h1>  {/* Header of the app */}
      </header>
      <main>
        {/* Render the TreeMap component only if cloneData is loaded */}
        {cloneData ? (
          <TreeMap data={cloneData} />  // Pass the clone data as a prop to TreeMap
        ) : (
          <p>Loading...</p>  // Show a loading message if data is not yet available
        )}
      </main>
    </div>
  );
};

export default App;  // Export the App component to be used in index.js
