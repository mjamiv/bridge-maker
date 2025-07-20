import React, { useState, useMemo, useRef, useEffect } from 'react';
import * as THREE from 'three';
import { Canvas } from '@react-three/fiber';
import { OrbitControls, OrthographicCamera, PerspectiveCamera, Edges } from '@react-three/drei';

// Assumes exportToDXF(scene) for DXF export
export default function BridgePierGeometryTool() {
  // --- State (inches) ---
  const [rowsL, setRowsL] = useState(3);
  const [rowsW, setRowsW] = useState(6);
  const [spacing, setSpacing] = useState(144);
  const [edgeDist, setEdgeDist] = useState(48);
  const [pileDia, setPileDia] = useState(48);
  const [capThk, setCapThk] = useState(144);
  const [embed, setEmbed] = useState(12);
  const [pileLen, setPileLen] = useState(1200);

  // Columns
  const [colCount, setColCount] = useState(2);
  const [colSpacing, setColSpacing] = useState(432);
  const [colShape, setColShape] = useState('rectangular');
  const [colW, setColW] = useState(168);
  const [colD, setColD] = useState(132);
  const [colH, setColH] = useState(2038);

  // Pier cap
  const [pierW, setPierW] = useState(1098);
  const [pierInset, setPierInset] = useState(237);
  const [pierL, setPierL] = useState(144);
  const [pierThk, setPierThk] = useState(144);
  const [pierTipThk, setPierTipThk] = useState(96);

  // Enhancements
  // Girders
  const [girderCount, setGirderCount] = useState(8);
  const [girderSpacing, setGirderSpacing] = useState(36);
  const [girderW, setGirderW] = useState(12);
  const [girderD, setGirderD] = useState(24);

  // derive girder positions across deck width
  const girderPos = useMemo(() => {
    const arr = [];
    const n = Math.max(1, girderCount);
    const total = girderSpacing * (n - 1);
    for (let i = 0; i < n; i++) arr.push(-total/2 + i * girderSpacing);
    return arr;
  }, [girderCount, girderSpacing]);
  const [spanCount, setSpanCount] = useState(2);
  const [spanLength, setSpanLength] = useState(1800);
  const [roadSlope, setRoadSlope] = useState(0.015);
  const [usePerspective, setUsePerspective] = useState(true);
  const [wireframe, setWireframe] = useState(false);
  const [edgesVisible, setEdgesVisible] = useState(false);
  const [fitToScreen, setFitToScreen] = useState(false);

  // Curve settings
  const [useCurve, setUseCurve] = useState(false);
  const [curveRadius, setCurveRadius] = useState(10000);
  const [curveStartAngle, setCurveStartAngle] = useState(0);
  const [curveDirection, setCurveDirection] = useState('left');

  // --- Derived Data ---
  const { capW, capL, pilePos } = useMemo(() => {
    const w = 2 * edgeDist + (rowsW - 1) * spacing + rowsW * pileDia;
    const l = 2 * edgeDist + (rowsL - 1) * spacing + rowsL * pileDia;
    const pos = [];
    for (let i = 0; i < rowsL; i++) {
      for (let j = 0; j < rowsW; j++) {
        pos.push([
          -w/2 + edgeDist + pileDia/2 + j*(spacing+pileDia),
          -l/2 + edgeDist + pileDia/2 + i*(spacing+pileDia)
        ]);
      }
    }
    return { capW: w, capL: l, pilePos: pos };
  }, [rowsL, rowsW, spacing, edgeDist, pileDia]);

  const pileTopY = -capThk + embed;
  const pileCenterY = pileTopY - pileLen/2;
  const baseColH = colH - pierThk;

  const colsPos = useMemo(() => {
    const arr = [];
    const n = Math.max(1, Math.min(colCount, 4));
    const gap = colSpacing*(n-1);
    for (let i = 0; i < n; i++) arr.push([-gap/2 + i*colSpacing, 0]);
    return arr;
  }, [colCount, colSpacing]);

  const pierInfos = useMemo(() => {
    const infos = [];
    const total = spanCount * spanLength;
    if (useCurve && curveRadius > 0) {
      const sign = curveDirection === 'left' ? 1 : -1;
      const startRad = THREE.MathUtils.degToRad(curveStartAngle);
      const delta = spanLength/curveRadius * sign;
      for (let i = 0; i <= spanCount; i++) {
        const theta = startRad + i*delta;
        const x = curveRadius*Math.cos(theta) - curveRadius*Math.cos(startRad);
        const z = curveRadius*Math.sin(theta) - curveRadius*Math.sin(startRad);
        const elev = i*spanLength*roadSlope;
        const tangent = theta + sign*Math.PI/2;
        infos.push({ x, z, elev, rotY: -tangent + Math.PI/2 });
      }
    } else {
      const start = -total/2;
      for (let i = 0; i <= spanCount; i++) {
        infos.push({ x:0, z: start + i*spanLength, elev: i*spanLength*roadSlope, rotY: 0 });
      }
    }
    return infos;
  }, [useCurve, curveRadius, curveStartAngle, curveDirection, spanCount, spanLength, roadSlope]);

  const pierShape = useMemo(() => {
    const half = pierW/2;
    const overhang = Math.min(pierInset, half);
    const yTop = pierThk/2;
    const yBot = -pierThk/2;
    const yTip = yTop - pierTipThk;
    const shape = new THREE.Shape();
    shape.moveTo(-half, yTop);
    shape.lineTo(half, yTop);
    shape.lineTo(half, yTip);
    shape.lineTo(half-overhang, yBot);
    shape.lineTo(-half+overhang, yBot);
    shape.lineTo(-half, yTip);
    shape.closePath();
    return shape;
  }, [pierW, pierThk, pierInset, pierTipThk]);

  const pileCapVol = capW/12 * capL/12 * capThk/12;
  const pierCapVol = pierW/12 * pierL/12 * pierThk/12;

  const maxDim = useMemo(() => Math.max(capW, capL, pileLen, baseColH + spanCount*spanLength*roadSlope + pierThk, pierW, spanCount*spanLength),
    [capW, capL, pileLen, baseColH, spanCount, spanLength, roadSlope, pierW]
  );
  const camDist = maxDim*2;

  const controlsRef = useRef();
  useEffect(() => { if (fitToScreen && controlsRef.current) { controlsRef.current.reset(); setFitToScreen(false);} }, [fitToScreen]);

  const handlePrint = () => window.print();
  const handleDXF = () => { if (typeof exportToDXF==='function') exportToDXF(); else alert('Not available'); };

  return (
    <div className="flex h-screen font-sans">
      <aside className="w-80 p-4 bg-gray-100 shadow-lg overflow-auto space-y-4">
        <div className="flex justify-between items-center">
          <h2 className="text-2xl font-bold">Configurator</h2>
          <div className="space-x-2">
            <button onClick={handlePrint} className="px-3 py-1 bg-blue-600 text-white rounded">Print</button>
            <button onClick={handleDXF} className="px-3 py-1 bg-green-600 text-white rounded">DXF</button>
          </div>
        </div>
        {/* Alignment */}
        <details open className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">Alignment</summary>
          <div className="p-3 grid grid-cols-2 gap-3 text-sm">
            <label><input type="checkbox" checked={useCurve} onChange={()=>setUseCurve(!useCurve)} className="mr-1"/>Use Curve</label>
            <div></div>
            {useCurve && <>  <label>Radius<input type="number" value={curveRadius} onChange={e=>setCurveRadius(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Start Angle<input type="number" value={curveStartAngle} onChange={e=>setCurveStartAngle(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Direction<select value={curveDirection} onChange={e=>setCurveDirection(e.target.value)} className="w-full p-1 border rounded"><option value="left">Left</option><option value="right">Right</option></select></label></>}
          </div>
        </details>
        {/* Pile Grid */}
        <details className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">Pile Grid</summary>
          <div className="p-3 grid grid-cols-2 gap-3 text-sm">
            <label>Rows L<input type="number" value={rowsL} onChange={e=>setRowsL(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Rows W<input type="number" value={rowsW} onChange={e=>setRowsW(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Spacing<input type="number" value={spacing} onChange={e=>setSpacing(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Edge Dist<input type="number" value={edgeDist} onChange={e=>setEdgeDist(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Dia<input type="number" value={pileDia} onChange={e=>setPileDia(+e.target.value)} className="w-full p-1 border rounded"/></label>
          </div>
        </details>
        {/* Pile Cap */}
        <details className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">Pile Cap</summary>
          <div className="p-3 grid grid-cols-2 gap-3 text-sm">
            <label>Depth<input type="number" value={capThk} onChange={e=>setCapThk(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Embed<input type="number" value={embed} onChange={e=>setEmbed(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Length<input type="number" value={pileLen} onChange={e=>setPileLen(+e.target.value)} className="w-full p-1 border rounded"/></label>
          </div>
        </details>
        {/* Columns */}
        <details className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">Columns</summary>
          <div className="p-3 grid grid-cols-3 gap-3 text-sm">
            <label>Count<input type="number" min={1} max={4} value={colCount} onChange={e=>setColCount(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Spacing<input type="number" value={colSpacing} onChange={e=>setColSpacing(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Shape<select value={colShape} onChange={e=>setColShape(e.target.value)} className="w-full p-1 border rounded"><option value="rectangular">Rectangular</option><option value="circular">Circular</option></select></label>
            <label>W<input type="number" value={colW} onChange={e=>setColW(+e.target.value)} className="w-full p-1 border rounded"/></label>
            {colShape==='rectangular' && <label>D<input type="number" value={colD} onChange={e=>setColD(+e.target.value)} className="w-full p-1 border rounded"/></label>}
            <label>H<input type="number" value={colH} onChange={e=>setColH(+e.target.value)} className="w-full p-1 border rounded"/></label>
          </div>
        </details>
        {/* Pier Cap */}
        <details className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">Pier Cap</summary>
          <div className="p-3 grid grid-cols-3 gap-3 text-sm">
            <label>Width<input type="number" value={pierW} onChange={e=>setPierW(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Overhang<input type="number" value={pierInset} onChange={e=>setPierInset(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Tip Thk<input type="number" value={pierTipThk} onChange={e=>setPierTipThk(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Length<input type="number" value={pierL} onChange={e=>setPierL(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Depth<input type="number" value={pierThk} onChange={e=>setPierThk(+e.target.value)} className="w-full p-1 border rounded"/></label>
          </div>
        </details>
        {/* Spans & Slope */}
        <details className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">Spans & Slope</summary>
          <div className="p-3 grid grid-cols-2 gap-3 text-sm">
            <label># Spans<input type="number" min={1} value={spanCount} onChange={e=>setSpanCount(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Span Len<input type="number" value={spanLength} onChange={e=>setSpanLength(+e.target.value)} className="w-full p-1 border rounded"/></label>
            <label>Road Slope<input type="number" step="0.001" value={roadSlope} onChange={e=>setRoadSlope(+e.target.value)} className="w-full p-1 border rounded"/></label>
          </div>
        </details>
        {/* View Options */}
        <details className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">View</summary>
          <div className="p-3 space-y-2 text-sm">
            <label><input type="checkbox" checked={usePerspective} onChange={()=>setUsePerspective(!usePerspective)} className="mr-1"/>Perspective</label>
            <label><input type="checkbox" checked={wireframe} onChange={()=>setWireframe(!wireframe)} className="mr-1"/>Wireframe</label>
            <label><input type="checkbox" checked={edgesVisible} onChange={()=>setEdgesVisible(!edgesVisible)} className="mr-1"/>Solid Edges</label>
            <button onClick={()=>setFitToScreen(true)} className="mt-1 px-2 py-1 bg-gray-200 rounded">Fit Screen</button>
          </div>
        </details>
        {/* Quantities */}
        <details className="bg-white border rounded">
          <summary className="px-3 py-1 font-medium cursor-pointer">Quantities</summary>
          <div className="p-3 text-sm space-y-2">
            {pierInfos.map(({elev},i)=>{
              const np = rowsL*rowsW;
              const tl = np*pileLen;
              const ch = baseColH + elev;
              const cv = (colW/12)*(colShape==='rectangular'?colD/12:Math.PI*(colW/2/12)**2)*(ch/12)*colCount;
              return (
                <div key={i} className="border-b pb-1">
                  <div className="font-semibold">Pier {i+1}</div>
                  <div># Piles: {np}</div>
                  <div>Total Pile Len: {tl} in</div>
                  <div>P Cap Vol: {pileCapVol.toFixed(2)} ft³</div>
                  <div>Col Vol: {cv.toFixed(2)} ft³</div>
                  <div>Pier Cap Vol: {pierCapVol.toFixed(2)} ft³</div>
                </div>
              );
            })}
            <div className="mt-2 font-semibold">Overall</div>
            <div>Total Piers: {pierInfos.length}</div>
            <div>Total Piles: {pierInfos.length * rowsL * rowsW}</div>
            <div>Total Pile Len: {pierInfos.length * rowsL * rowsW * pileLen} in</div>
            <div>Total P Cap Vol: {(pierInfos.length * pileCapVol).toFixed(2)} ft³</div>
            <div>Total Col Vol: {(pierInfos.reduce((s,{elev})=>s + (colW/12)*(colShape==='rectangular'?colD/12:Math.PI*(colW/2/12)**2)*((baseColH+elev)/12)*colCount,0)).toFixed(2)} ft³</div>
            <div>Total Pier Cap Vol: {(pierInfos.length * pierCapVol).toFixed(2)} ft³</div>
          </div>
        </details>
      </aside>
      <main className="flex-1 bg-white">
        <Canvas shadows>
          {usePerspective
            ? <PerspectiveCamera makeDefault position={[camDist,camDist,camDist]} fov={50} near={0.1} far={camDist*3} />
            : <OrthographicCamera makeDefault position={[camDist,camDist,camDist]} zoom={0.7} near={0.1} far={camDist*3} />
          }
          <ambientLight intensity={0.6}/>
          <directionalLight position={[camDist,camDist,camDist]} intensity={0.4}/>
          {pierInfos.map(({x,z,elev,rotY},idx)=>(
            <group key={idx} position={[x,0,z]} rotation={[0,rotY,0]}>
              <mesh position={[0,-capThk/2,0]}> <boxGeometry args={[capW,capThk,capL]}/> <meshStandardMaterial wireframe={wireframe} color="lightgray" transparent opacity={0.5} depthWrite={false}/> {edgesVisible && <Edges color="black"/>} </mesh>
              <mesh position={[0, baseColH + elev + pierThk/2, -pierL/2]}> <extrudeGeometry args={[pierShape,{depth: pierL, bevelEnabled:false}]}/> <meshStandardMaterial wireframe={wireframe} color="darkgray"/> {edgesVisible && <Edges color="black"/>} </mesh>
              {pilePos.map(([px,pz],i)=><mesh key={`pile-${idx}-${i}`} position={[px,pileCenterY,pz]}> <cylinderGeometry args={[pileDia/2,pileDia/2,pileLen,16]}/> <meshStandardMaterial wireframe={wireframe} color="steelblue" transparent opacity={0.7}/> {edgesVisible && <Edges color="black"/>} </mesh>)}
              {colsPos.map(([cx,cz],i)=><mesh key={`col-${idx}-${i}`} position={[cx,(baseColH+elev)/2,cz]}> {colShape==='circular'?<cylinderGeometry args={[colW/2,colW/2,baseColH+elev,16]}/>:<boxGeometry args={[colW,baseColH+elev,colD]}/>} <meshStandardMaterial wireframe={wireframe} color="tomato"/> {edgesVisible && <Edges color="black"/>} </mesh>)}
            </group>
          ))}
          <OrbitControls ref={controlsRef}/>
        </Canvas>
      </main>
    </div>
  );
}
