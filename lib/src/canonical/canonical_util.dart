import 'package:rdf_core/rdf_core.dart';

enum CanonicalHashAlgorithm { sha256, sha384 }

class CanonicalizationOptions {
  final CanonicalHashAlgorithm hashAlgorithm;
  final String blankNodePrefix;

  const CanonicalizationOptions(
      {this.hashAlgorithm = CanonicalHashAlgorithm.sha256,
      this.blankNodePrefix = 'c14n'});
}

class CanonicalizedRdfDataset {
  final RdfDataset inputDataset;
  // Optional: if input was provided in a way that blank nodes had labels,
  // this map contains the mapping from blank node terms to their original labels.
  final Map<BlankNodeTerm, String>? inputIdentifiers;
  final Map<BlankNodeTerm, String> issuedIdentifiers;

  CanonicalizedRdfDataset(
      {required this.inputDataset,
      required this.inputIdentifiers,
      required this.issuedIdentifiers});
}

CanonicalizedRdfDataset toCanonicalizedRdfDataset(RdfDataset dataset,
    {Map<BlankNodeTerm, String>? inputLabels,
    CanonicalizationOptions? options}) {
  // Implementation here
  throw UnimplementedError();
}

CanonicalizedRdfDataset toCanonicalizedRdfDatasetFromNQuads(String nquads,
    {CanonicalizationOptions? options}) {
  NQuadsDecoder decoder = NQuadsDecoder();
  final (blankNodeLabels: inputLabels, dataset: inputDataset) =
      decoder.decode(nquads);

  return toCanonicalizedRdfDataset(inputDataset,
      inputLabels: inputLabels, options: options);
}

String toNQuads(CanonicalizedRdfDataset canonicalized,
    {CanonicalizationOptions? options}) {
  NQuadsEncoder encoder = NQuadsEncoder();
  return encoder.encode(canonicalized.inputDataset,
      blankNodeLabels: canonicalized.issuedIdentifiers,
      canonical: true,
      generateNewBlankNodeLabels: false);
}

/// https://www.w3.org/TR/rdf-canon/#canonicalization states: "Canonicalization is the process of transforming an input dataset to its serialized canonical form"
String canonicalize(RdfDataset dataset, {CanonicalizationOptions? options}) {
  options ??= const CanonicalizationOptions();
  final canonicalized = toCanonicalizedRdfDataset(dataset, options: options);
  return toNQuads(canonicalized, options: options);
}

String canonicalizeGraph(RdfGraph graph, {CanonicalizationOptions? options}) {
  return canonicalize(RdfDataset.fromDefaultGraph(graph), options: options);
}

bool isIsomorphic(RdfDataset a, RdfDataset b,
    {CanonicalizationOptions? options}) {
  options ??= const CanonicalizationOptions();
  final canA = canonicalize(a, options: options);
  final canB = canonicalize(b, options: options);

  // Two datasets are isomorphic if their canonical serializations match
  return canA == canB;
}

bool isIsomorphicGraphs(RdfGraph a, RdfGraph b,
    {CanonicalizationOptions? options}) {
  final canA = canonicalizeGraph(a, options: options);
  final canB = canonicalizeGraph(b, options: options);

  // Two graphs are isomorphic if their canonical serializations match
  return canA == canB;
}
