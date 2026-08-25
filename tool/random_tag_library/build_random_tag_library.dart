import 'verify_random_tag_library.dart' as verifier;

/// Rebuilds deterministic counts and hashes after an intentional taxonomy edit.
///
/// Candidate text is never emitted: all rows remain in the pinned catalog and
/// the generated source lock records only provenance and aggregate counts.
Future<void> main() => verifier.verifyRandomTagLibrary(updateLock: true);
