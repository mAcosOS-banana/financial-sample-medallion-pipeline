import re
import unicodedata
 
# Conectores em português e em inglês. Ajuste a lista se precisar.
CONECTORES = frozenset({
    # português
    "de", "da", "do", "das", "dos", "e", "d",
    # inglês
    "of", "the", "and",
})
 
 
def normalizar_nome(nome: str, minusculas: bool = True, remover_acentos: bool = True,
                    conectores: frozenset = CONECTORES) -> str:
    """Normaliza um nome.
 
    Passos, nesta ordem:
    1. Normaliza o Unicode (NFKD) e, se pedido, remove os acentos.
    2. Troca espaços (um ou mais) por "_".
    3. Remove os conectores entre "_" (ex.: "_de_", "_do_", "_e_", "_of_", "_and_").
 
    Conectores no início ou no fim do nome não são removidos, porque não ficam entre "_".
 
    >>> normalizar_nome("José da Silva e Souza")
    'jose_silva_souza'
    >>> normalizar_nome("Bank of the West")
    'bank_west'
    """
    if not nome:
        return ""
 
    # 1. Normalização Unicode
    texto = unicodedata.normalize("NFKD", nome)
    if remover_acentos:
        texto = "".join(c for c in texto if not unicodedata.combining(c))
    else:
        texto = unicodedata.normalize("NFC", texto)
    if minusculas:
        texto = texto.lower()
 
    # 2. Espaços para "_"
    texto = re.sub(r"\s+", "_", texto.strip())
 
    # 3. Remove conectores entre "_". O lookahead trata conectores seguidos ("_de_e_").
    padrao = r"_(?:" + "|".join(sorted(map(re.escape, conectores), key=len, reverse=True)) + r")(?=_)"
    flags = re.IGNORECASE
    anterior = None
    while anterior != texto:
        anterior = texto
        texto = re.sub(padrao, "", texto, flags=flags)
 
    return re.sub(r"_+", "_", texto)