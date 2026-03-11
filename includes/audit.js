function getBatchId() {
  // Usamos return de un string que contiene la variable de dataform
  // La barra invertida \$ es el truco para que funcione en la compilación
  return `${dataform.projectConfig.vars.batchId || 'manual'}`;
}

function getFileName() {
  // Retorna el valor de la variable o 'N/A' si no existe
  return `"${dataform.projectConfig.vars.currentFile || 'N/A'}"`;
}

module.exports = {
  getBatchId,
  getFileName
};