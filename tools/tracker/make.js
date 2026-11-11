// Builds Iron Front tracker .xlsx (no libraries): zip with deflate + SpreadsheetML.
const zlib = require("zlib"), fs = require("fs"), path = require("path");
const D = require("./data.js");
const IDEA_ROWS = 200;

const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const col = n => { let s = ""; n++; while (n) { const m = (n - 1) % 26; s = String.fromCharCode(65 + m) + s; n = Math.floor((n - 1) / 26); } return s; };

// cell: string -> text, {f} -> formula, number -> number; style index s
function cell(ref, v, s) {
  const st = s ? ` s="${s}"` : "";
  if (v === null || v === undefined || v === "") return s ? `<c r="${ref}"${st}/>` : "";
  if (typeof v === "number") return `<c r="${ref}"${st}><v>${v}</v></c>`;
  if (typeof v === "object") return `<c r="${ref}"${st}><f>${esc(v.f)}</f></c>`;
  return `<c r="${ref}"${st} t="inlineStr"><is><t xml:space="preserve">${esc(v)}</t></is></c>`;
}
function sheet({ rows, widths, freeze, colStyles = {}, filter, cf = "", dv = [], merges = [] }) {
  let x = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">`;
  x += `<sheetViews><sheetView workbookViewId="0">`;
  if (freeze) x += `<pane xSplit="${freeze[0]}" ySplit="${freeze[1]}" topLeftCell="${col(freeze[0])}${freeze[1] + 1}" activePane="bottomRight" state="frozen"/>`;
  x += `</sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols>`;
  widths.forEach((w, i) => { const cs = colStyles[i] ? ` style="${colStyles[i]}"` : ""; x += `<col min="${i + 1}" max="${i + 1}" width="${w}" customWidth="1"${cs}/>`; });
  x += `</cols><sheetData>`;
  rows.forEach((r, ri) => {
    if (!r) return;
    x += `<row r="${ri + 1}">`;
    r.cells.forEach((v, ci) => { x += cell(col(ci) + (ri + 1), v, Array.isArray(r.s) ? r.s[ci] : r.s); });
    x += `</row>`;
  });
  x += `</sheetData>`;
  if (filter) x += `<autoFilter ref="${filter}"/>`;
  if (merges.length) x += `<mergeCells count="${merges.length}">${merges.map(m => `<mergeCell ref="${m}"/>`).join("")}</mergeCells>`;
  x += cf;
  if (dv.length) x += `<dataValidations count="${dv.length}">${dv.map(([sq, f]) => `<dataValidation type="list" allowBlank="1" showErrorMessage="1" sqref="${sq}"><formula1>${f}</formula1></dataValidation>`).join("")}</dataValidations>`;
  return x + `</worksheet>`;
}
// styles: 0 default, 1 header, 2 body wrap, 3 input (yellow, wrap), 4 title, 5 bold label, 6 formula cell (wrap, grey text)
const styles = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="5"><font><sz val="10"/><name val="Arial"/></font><font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="Arial"/></font><font><b/><sz val="14"/><name val="Arial"/></font><font><b/><sz val="10"/><name val="Arial"/></font><font><sz val="10"/><color rgb="FF444444"/><name val="Arial"/></font></fonts>
<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF4B5320"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF2CC"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="7">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyAlignment="1"><alignment vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="3" borderId="0" xfId="0" applyFill="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>
</cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
<dxfs count="3"><dxf><font><b/><color rgb="FF990000"/></font><fill><patternFill><bgColor rgb="FFF4CCCC"/></patternFill></fill></dxf><dxf><font><color rgb="FF7F4F00"/></font><fill><patternFill><bgColor rgb="FFFCE5CD"/></patternFill></fill></dxf><dxf><font><color rgb="FF274E13"/></font><fill><patternFill><bgColor rgb="FFD9EAD3"/></patternFill></fill></dxf></dxfs>
</styleSheet>`;

// ---- Lists tab
const L = [];
L[0] = { cells: ["Side", "What it covers", "Built", "Ideas", "", "Type", "Built", "Ideas", "", "Built status", "Idea status", "Priority", "Size"], s: 1 };
const nL = Math.max(D.sides.length, D.types.length, D.ideaStatus.length);
for (let i = 0; i < nL; i++) {
  const r = i + 2, c = new Array(13).fill("");
  if (D.sides[i]) { c[0] = D.sides[i][0]; c[1] = D.sides[i][1]; c[2] = { f: `COUNTIF(Built!$C:$C,A${r})` }; c[3] = { f: `COUNTIF(Ideas!$C:$C,A${r})` }; }
  if (D.types[i]) { c[5] = D.types[i]; c[6] = { f: `COUNTIF(Built!$D:$D,F${r})` }; c[7] = { f: `COUNTIF(Ideas!$D:$D,F${r})` }; }
  c[9] = D.builtStatus[i] || ""; c[10] = D.ideaStatus[i] || ""; c[11] = D.priority[i] || ""; c[12] = D.size[i] || "";
  L[i + 1] = { cells: c, s: 2 };
}
const lastSide = D.sides.length + 1, lastType = D.types.length + 1;
L[lastType + 1] = { cells: ["Total", "", { f: `SUM(C2:C${lastSide})` }, { f: `SUM(D2:D${lastSide})` }, "", "Total", { f: `SUM(G2:G${lastType})` }, { f: `SUM(H2:H${lastType})` }], s: 5 };
const listsXml = sheet({ rows: L, widths: [16, 44, 8, 8, 3, 12, 8, 8, 3, 24, 24, 10, 10], freeze: [0, 1] });
const R = (c, n) => `Lists!$${c}$2:$${c}$${n + 1}`;

// ---- Built tab
const BH = ["ID", "Name", "Side", "Type", "Group", "Status", "Weapons", "Crew / carries", "Animations done", "Videos / pictures", "Job and abilities in game", "Still missing", "Notes"];
const B = [{ cells: BH, s: 1 }, ...D.built.map(r => ({ cells: r, s: 2 }))];
const nB = D.built.length + 1, bEnd = 500;
const builtCf = `<conditionalFormatting sqref="B2:B${bEnd}"><cfRule type="expression" dxfId="0" priority="1"><formula>AND($B2&lt;&gt;"",COUNTIF($B$2:$B$${bEnd},$B2)&gt;1)</formula></cfRule></conditionalFormatting>` +
  `<conditionalFormatting sqref="A2:A${bEnd}"><cfRule type="expression" dxfId="0" priority="2"><formula>AND($A2&lt;&gt;"",COUNTIF($A$2:$A$${bEnd},$A2)&gt;1)</formula></cfRule></conditionalFormatting>`;
const builtXml = sheet({
  rows: B, widths: [8, 28, 13, 11, 20, 12, 24, 22, 40, 30, 38, 30, 28], freeze: [2, 1], filter: `A1:M${nB}`, cf: builtCf,
  dv: [[`C2:C${bEnd}`, R("A", D.sides.length)], [`D2:D${bEnd}`, R("F", D.types.length)], [`F2:F${bEnd}`, R("J", D.builtStatus.length)]],
});

// ---- Ideas tab
const IH = ["ID", "Name", "Side", "Type", "What it is", "Weapons", "Crew / carries", "Animations needed", "Abilities needed", "Builds on (Built ID)", "Priority", "Size", "Status", "Same name in Built", "Check"];
const I = [{ cells: IH, s: 1 }];
for (let i = 0; i < IDEA_ROWS; i++) {
  const r = i + 2, src = D.ideas[i] || [`N-${String(i + 1).padStart(3, "0")}`];
  const c = new Array(15).fill("");
  src.forEach((v, k) => c[k] = v);
  c[13] = { f: `IF(B${r}="","",IFERROR(INDEX(Built!$A:$A,MATCH(B${r},Built!$B:$B,0)),""))` };
  c[14] = { f: `IF(B${r}="","",IF(N${r}<>"","Already built",IF(COUNTIF($B$2:$B$${IDEA_ROWS + 1},B${r})>1,"Listed twice",IF(COUNTIF(Built!$B:$B,"*"&B${r}&"*")>0,"Similar name in Built","New"))))` };
  const s = c.map((_, k) => k === 0 ? 2 : k >= 13 ? 6 : 3);
  I.push({ cells: c, s });
}
const iEnd = IDEA_ROWS + 1;
const ideasCf = `<conditionalFormatting sqref="O2:O${iEnd}">` +
  `<cfRule type="containsText" dxfId="0" priority="1" operator="containsText" text="Already built"><formula>NOT(ISERROR(SEARCH("Already built",O2)))</formula></cfRule>` +
  `<cfRule type="containsText" dxfId="0" priority="2" operator="containsText" text="Listed twice"><formula>NOT(ISERROR(SEARCH("Listed twice",O2)))</formula></cfRule>` +
  `<cfRule type="containsText" dxfId="1" priority="3" operator="containsText" text="Similar"><formula>NOT(ISERROR(SEARCH("Similar",O2)))</formula></cfRule>` +
  `<cfRule type="cellIs" dxfId="2" priority="4" operator="equal"><formula>"New"</formula></cfRule></conditionalFormatting>`;
const ideasXml = sheet({
  rows: I, widths: [8, 28, 13, 11, 36, 22, 20, 32, 32, 12, 9, 9, 18, 12, 18], freeze: [2, 1], filter: `A1:O${iEnd}`, cf: ideasCf,
  dv: [[`C2:C${iEnd}`, R("A", D.sides.length)], [`D2:D${iEnd}`, R("F", D.types.length)], [`K2:K${iEnd}`, R("L", D.priority.length)],
    [`L2:L${iEnd}`, R("M", D.size.length)], [`M2:M${iEnd}`, R("K", D.ideaStatus.length)]],
});

// ---- How to use tab
const H = [
  { cells: ["Iron Front: what we have built, and what comes next"], s: 4 }, null,
  { cells: ["Tab", "What it holds"], s: 1 },
  { cells: ["Built", "Every unit, building, prop and effect built and approved so far, by side. One row each, with an ID (U infantry, V vehicles, T trains, A air, P props, R red jackets, Z zombies, B buildings, E effects)."], s: [5, 2] },
  { cells: ["Ideas", "New units, buildings and anything else you want, one per row. The ID is already filled in; type the name and the rest."], s: [5, 2] },
  { cells: ["Lists", "The choices for the drop-downs (side, type, status, priority, size), with counts per side and type."], s: [5, 2] }, null,
  { cells: ["Colours", ""], s: 1 },
  { cells: ["Yellow cells", "Yours to fill in (Ideas tab)."], s: [3, 2] },
  { cells: ["Grey text", "Worked out by formula; leave these alone."], s: [6, 2] },
  { cells: ["Red check", "\"Already built\" (the exact name is on the Built tab) or \"Listed twice\" (the name is on the Ideas tab more than once). A red name or ID on the Built tab means a repeat there too."], s: [5, 2] },
  { cells: ["Amber check", "\"Similar name in Built\": the name is part of a built name, so look before adding it (for example \"Zombie\" matches all three zombies)."], s: [5, 2] },
  { cells: ["Green check", "\"New\": not found anywhere."], s: [5, 2] }, null,
  { cells: ["For the weekend plan", ""], s: 1 },
  { cells: ["Builds on", "Put the Built ID it reuses (an MG lorry builds on V-001, the troop lorry), so the plan can reuse bodies, moves and clip tools."], s: [5, 2] },
  { cells: ["Animations needed", "Each move that is new for this unit; moves it shares with its base (walk, fire, die) need not be listed."], s: [5, 2] },
  { cells: ["Abilities needed", "What it does in game. Nothing on the Built tab is wired to game control yet, so this column feeds the coding plan as well."], s: [5, 2] },
  { cells: ["Status", "Set \"Planned for the weekend\" on the ones to build; filter on it to make the plan."], s: [5, 2] }, null,
  { cells: ["Counts", ""], s: 1 },
  { cells: ["Built items", { f: "COUNTA(Built!A2:A)" }], s: [5, 2] },
  { cells: ["Ideas listed", { f: `COUNTA(Ideas!B2:B${iEnd})` }], s: [5, 2] },
  { cells: ["Ideas flagged red", { f: `COUNTIF(Ideas!O2:O${iEnd},"Already built")+COUNTIF(Ideas!O2:O${iEnd},"Listed twice")` }], s: [5, 2] },
  { cells: ["Planned for the weekend", { f: `COUNTIF(Ideas!M2:M${iEnd},"Planned for the weekend")` }], s: [5, 2] }, null,
  { cells: ["Source", "Built tab taken from the Iron Front reports and approvals up to 10 Nov 2026 (git log of iron_front, ending at 5a28157 and ea65ad2)."], s: [5, 6] },
];
const howXml = sheet({ rows: H, widths: [24, 100] });

// ---- package
const sheets = [["How to use", howXml], ["Built", builtXml], ["Ideas", ideasXml], ["Lists", listsXml]];
const files = {
  "[Content_Types].xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${sheets.map((_, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join("")}</Types>`,
  "_rels/.rels": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
  "xl/workbook.xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${sheets.map(([n], i) => `<sheet name="${esc(n)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join("")}</sheets></workbook>`,
  "xl/_rels/workbook.xml.rels": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${sheets.map((_, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join("")}<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`,
  "xl/styles.xml": styles,
};
sheets.forEach(([, x], i) => files[`xl/worksheets/sheet${i + 1}.xml`] = x);

const crcT = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc32 = b => { let c = -1; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
const locals = [], centrals = []; let off = 0;
for (const [name, text] of Object.entries(files)) {
  const raw = Buffer.from(text, "utf8"), comp = zlib.deflateRawSync(raw), nm = Buffer.from(name), crc = crc32(raw);
  const lh = Buffer.alloc(30); lh.writeUInt32LE(0x04034b50, 0); lh.writeUInt16LE(20, 4); lh.writeUInt16LE(0, 6); lh.writeUInt16LE(8, 8);
  lh.writeUInt32LE(0, 10); lh.writeUInt32LE(crc, 14); lh.writeUInt32LE(comp.length, 18); lh.writeUInt32LE(raw.length, 22); lh.writeUInt16LE(nm.length, 26); lh.writeUInt16LE(0, 28);
  const ch = Buffer.alloc(46); ch.writeUInt32LE(0x02014b50, 0); ch.writeUInt16LE(20, 4); ch.writeUInt16LE(20, 6); ch.writeUInt16LE(0, 8); ch.writeUInt16LE(8, 10);
  ch.writeUInt32LE(0, 12); ch.writeUInt32LE(crc, 16); ch.writeUInt32LE(comp.length, 20); ch.writeUInt32LE(raw.length, 24); ch.writeUInt16LE(nm.length, 28);
  ch.writeUInt32LE(off, 42);
  locals.push(lh, nm, comp); centrals.push(ch, nm); off += 30 + nm.length + comp.length;
}
const cd = Buffer.concat(centrals), end = Buffer.alloc(22);
end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(Object.keys(files).length, 8); end.writeUInt16LE(Object.keys(files).length, 10);
end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(off, 16);
const out = path.join(__dirname, "Iron Front tracker.xlsx");
fs.writeFileSync(out, Buffer.concat([...locals, cd, end]));
console.log(out, fs.statSync(out).size, "bytes; built rows", D.built.length);
