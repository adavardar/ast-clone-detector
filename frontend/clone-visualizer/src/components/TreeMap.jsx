// components/TreeMap.jsx
import React, { useEffect, useRef } from 'react';
import * as d3 from 'd3';

const TreeMap = ({ data }) => {
  const svgRef = useRef(null);

  useEffect(() => {
    const width = 800;
    const height = 600;

    const svg = d3.select(svgRef.current)
      .attr('width', width)
      .attr('height', height);

    const root = d3.hierarchy(data)
      .sum(d => d.value) 
      .sort((a, b) => b.value - a.value);

    const treemap = d3.treemap()
      .size([width, height])
      .padding(1);

    treemap(root);

    svg.selectAll('rect')
      .data(root.leaves())
      .enter()
      .append('rect')
      .attr('x', d => d.x0)
      .attr('y', d => d.y0)
      .attr('width', d => d.x1 - d.x0)
      .attr('height', d => d.y1 - d.y0)
      .style('fill', '#69b3a2')
      .style('stroke', 'white')
      .style('stroke-width', 1);

    svg.selectAll('text')
      .data(root.leaves())
      .enter()
      .append('text')
      .attr('x', d => d.x0 + 5)
      .attr('y', d => d.y0 + 15)
      .text(d => d.data.name)
      .style('font-size', '12px')
      .style('fill', 'white');
  }, [data]);

  return (
    <svg ref={svgRef}></svg>
  );
};

export default TreeMap;
