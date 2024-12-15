import React from 'react';
import TreeMap from '../components/TreeMap';  // Import TreeMap component
import cloningData from '../data/cloning_data.json';  // Import the JSON data

const Dashboard = () => {
  // Format the data for TreeMap, ensure that NumberOfLines is a number
  const transformedData = {
    name: 'Code Clones',  // Root node of the TreeMap
    children: cloningData["Type-1"].ExampleClones.map(clone => ({
      name: `${clone.Pair1} & ${clone.Pair2}`,  // Name of the clone pair
      value: parseInt(clone.NumberOfLines, 10),  // Convert NumberOfLines to an integer
    }))
  };

  return (
    <div>
      <h1>Code Clone Detection TreeMap</h1>
      <TreeMap data={transformedData} />  {/* Pass the formatted data to TreeMap */}
    </div>
  );
};

export default Dashboard;
