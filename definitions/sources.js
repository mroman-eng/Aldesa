const tables = [
  "proj",
  "prps",
  "bseg_jorge",
  "kna1_jorge",
  "lfa1_jorge",
  "mara_jorge",
  // ... añade aquí los otros 45 nombres
];

tables.forEach(table => {
  declare({
    database: "data-ai-lab-485911",
    schema: "raw",
    name: table
  });
});
