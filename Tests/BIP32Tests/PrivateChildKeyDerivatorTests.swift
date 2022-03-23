import XCTest
import CryptoSwift
import BIP32

final class PrivateChildKeyDerivatorTests: XCTestCase {
    private var privateMasterKeyDerivator: PrivateMasterKeyDerivator!
    private var publicMasterKeyDerivator: PublicMasterKeyDerivator!
    private var publicChildKeyDerivator: PublicChildKeyDerivator!
    private var keyVersion: UInt32!
    private var keyFingerprintDerivator: KeyFingerprintDerivator!
    private var keyIndexHardener: KeyIndexHardener!
    private var keySerializer: KeySerializer!
    private var serializedKeyCoder: SerializedKeyCoder!
    private var testVectors: [KeyTestVector]!

    override func setUpWithError() throws {
        privateMasterKeyDerivator = .init()
        publicMasterKeyDerivator = .init()
        publicChildKeyDerivator = .init()
        keyVersion = BitcoinVersion(network: .mainnet, keyAccessControl: .`private`).wrappedValue
        keyFingerprintDerivator = .init()
        keyIndexHardener = .init()
        keySerializer = .init()
        serializedKeyCoder = .init()
        testVectors = try JSONDecoder().decode([KeyTestVector].self, from: keyTestData)
    }

    private func sut() -> PrivateChildKeyDerivator {
        .init()
    }

    func testGivenPrivateParentKey_WhenDerivatePrivateChildKey_ThenEqualVectorKey() throws {
        let sut = self.sut()

        for testVector in testVectors {
            let seed = Data(hex: testVector.hexEncodedSeed)
            var privateParentKey = try privateMasterKeyDerivator.privateMasterKey(seed: seed)

            for derivatedKey in testVector.derivatedKeys {
                guard derivatedKey.depth > 0 else {
                    continue
                }
                let publicParentKey = try publicChildKeyDerivator.publicKey(privateKey: privateParentKey)
                let childKeyIndex = derivatedKey.isIndexHardened
                    ? try keyIndexHardener.hardenedIndex(normalIndex: derivatedKey.index)
                    : derivatedKey.index
                let privateChildKey = try sut.privateChildKey(
                    privateParentKey: privateParentKey,
                    index: childKeyIndex
                )
                XCTAssertEqual(privateChildKey.key.count, 32)
                XCTAssertEqual(privateChildKey.chainCode.count, 32)

                let parentKeyFingerprint = keyFingerprintDerivator.fingerprint(publicKey: publicParentKey.key)
                let privateChildKeyAttributes = ChildKeyAttributes(
                    accessControl: .`private`,
                    version: keyVersion,
                    depth: derivatedKey.depth,
                    parentKeyFingerprint: parentKeyFingerprint,
                    index: childKeyIndex
                )
                let serializedChildKey = try keySerializer.serializedKey(
                    extendedKey: privateChildKey,
                    attributes: privateChildKeyAttributes
                )
                let encodedChildKey = serializedKeyCoder.encode(serializedKey: serializedChildKey)
                XCTAssertEqual(encodedChildKey, derivatedKey.base58CheckEncodedPrivateKey)
                privateParentKey = privateChildKey
            }
        }
    }
}
