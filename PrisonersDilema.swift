
protocol PrisonerStrategy: CustomStringConvertible {
    var isFirstPlay: Bool { get }
    mutating func choice() -> PDilemma.Choice
    mutating func otherPlayer(_: PDilemma.Choice)
}

extension PrisonerStrategy {
    func multipleRounds(opponent: Self, count: Int) -> [PDilemma.OneGame] {
        var result: [PDilemma.OneGame] = []
        var p1 = self
        var p2 = opponent
        assert(p1.isFirstPlay)
        assert(p2.isFirstPlay)
        for _ in 0 ..< count {
            let c1 = p1.choice()
            let c2 = p2.choice()
            result.append(.init(player: c1, opponent: c2))
            p1.otherPlayer(c2)
            p2.otherPlayer(c1)
        }
        return result
    }
    
    func computeSignature() -> String {
        var result = ""
        for a in 0 ... 1 {
            for b in 0 ... 1 {
                for c in 0 ... 1 {
                    var player = self
                    assert(player.isFirstPlay)
                    let c0 = player.choice()
                    player.otherPlayer(.init(a == 0))
                    let c1 = player.choice()
                    player.otherPlayer(.init(b == 0))
                    let c2 = player.choice()
                    player.otherPlayer(.init(c == 0))
                    let c3 = player.choice()
                    let code = c3.bit + 2 * c2.bit + 4 * c1.bit + 8 * c0.bit
                    result += String(code, radix: 16)
                    if result.count == 4 {
                        result += "-"
                    }
                }
            }
        }
        return result
    }
}

struct PDilemma {
    enum Choice {
        case cooperate
        case defect

        var bit: Int {
            switch self {
            case .defect: return 1
            case .cooperate: return 0
            }
        }

        init(_ isDefect: Bool) {
            if isDefect {
                self = .defect
            } else {
                self = .cooperate
            }
        }
    }
    
    enum Outcome: CaseIterable {
        case saint
        case thief
        case jerk
        case sucker
        
        init(_ player: Choice, opponent: Choice) {
            switch (player, opponent) {
            case (.cooperate, .cooperate):
                self = .saint
            case (.defect, .defect):
                self = .thief
            case (.defect, .cooperate):
                self = .jerk
            case (.cooperate, .defect):
                self = .sucker
            }
        }
        
        var game: OneGame {
            switch self {
            case .saint:
                return .init(player: .cooperate, opponent: .cooperate)
            case .thief:
                return .init(player: .defect, opponent: .defect)
            case .jerk:
                return .init(player: .defect, opponent: .cooperate)
            case .sucker:
                return .init(player: .cooperate, opponent: .defect)
            }
        }
        
        var payoff: Int {
            switch self {
            case .saint:
                return 3
            case .thief:
                return 1
            case .jerk:
                return 5
            case .sucker:
                return 0
            }
        }
    }

    struct OneGame {
        let player: Choice
        let opponent: Choice
        
        var outcome: Outcome {
            Outcome(player, opponent: opponent)
        }
        
        var score: Int {
            outcome.payoff
        }
    }
    
    struct Stats {
        var table: [Outcome: Int]
        
        init(outcomes: [Outcome] = []) {
            self.table = [:]
            for o in outcomes {
                add(o)
            }
        }
        
        mutating func add(_ outcome: Outcome) {
            table[outcome, default: 0] += 1
        }
        
        var count: Int {
            table.reduce(0) { $0 + $1.value }
        }
        
        var score: Int {
            table.reduce(0) { $0 + $1.value * $1.key.payoff }
        }
        
        func weight(_ key: Outcome) -> Float {
            Float(table[key, default: 0])
        }
        
        func normalizedScore(_ defecting: Float, _ cooperating: Float) -> Float {
            weight(.jerk) + weight(.saint) * cooperating + weight(.thief) * defecting
        }

        static func +(lhs: Stats, rhs: Stats) -> Stats {
            var result = lhs
            for (key, value) in rhs.table {
                result.table[key, default: 0] += value
            }
            return result
        }

        var summary: String {
            var result = ""
            for out in Outcome.allCases {
                let n = table[out, default: 0]
                result += "\(n)*\(out.payoff)=\(n * out.payoff) "
            }
            return result
        }
    }

    struct OneGameMemoryStrategy: PrisonerStrategy {
        let bits: [Bool]
        var myLast: PDilemma.Choice?
        var theirLast: PDilemma.Choice?
        var isFirstPlay = true
        
        mutating func choice() -> PDilemma.Choice {
            guard let mine = myLast, let theirs = theirLast else {
                assert(isFirstPlay)
                let firstPlay = PDilemma.Choice(bits[0])
                myLast = firstPlay
                isFirstPlay = false
                return firstPlay
            }
            assert(!isFirstPlay)
            let index = mine.bit + 2 * theirs.bit
            let play = PDilemma.Choice(bits[index + 1])
            myLast = play
            return play
        }

        mutating func otherPlayer(_ other: PDilemma.Choice) {
            theirLast = other
        }

        var description: String {
            bits.map({ String($0 ? 1 : 0) }).joined()
        }

        static var allSignatures: [String: String] {
            var result: [String: String] = [:]
            for x in 0 ... 31 {
                let name = x.binaryString(digits: 5)
                let sig = OneGameMemoryStrategy(name: name)!.computeSignature()
                result[name] = sig
                var decode = ""
                for digit in sig {
                    if digit == "-" {
                        decode += "  "
                    } else if let x = Int(String(digit), radix: 16) {
                        decode += x.binaryString(digits: 4) + " "
                    } else {
                        decode += "???? "
                    }
                }
                print("\(name)  \(sig)  |  \(decode)")
            }
            return result
        }
        
        static func redundant32() -> Tournament {
            let allSig = OneGameMemoryStrategy.allSignatures
            return .init(prototypes: allSig.keys.map( { OneGameMemoryStrategy(name: String($0))! }))
        }
        
        static func unique26() -> Tournament {
            let allSig = OneGameMemoryStrategy.allSignatures
            var protos: [OneGameMemoryStrategy] = []
            var uniqueSig: Set<String> = []
            func addSig(name: String, sig: String) {
                guard !uniqueSig.contains(sig) else { return }
                protos.append(.init(name: name)!)
                uniqueSig.insert(sig)
            }
            addSig(name: "00000", sig: allSig["00000"]!)
            addSig(name: "11111", sig: allSig["11111"]!)
            for (name, sig) in allSig {
                addSig(name: name, sig: sig)
            }
            return .init(prototypes: protos)
        }
    }
    
    struct Tournament {
        let prototypes: [OneGameMemoryStrategy]
        var stats: [Stats] = []
        var rank: [Float] = []

        mutating func computeRanking() {
            let count = prototypes.count
            stats = .init(repeating: .init(), count: count)
            for i1 in 0 ..< count {
                for i2 in 0 ..< count {
                    let games = prototypes[i1].multipleRounds(opponent: prototypes[i2], count: 200)
                    stats[i1] = stats[i1] + games.stats
                }
            }
            let scores = stats.map(\.score)
            let lo = scores.min()!
            let hi = scores.max()!
            rank = scores.map { Float($0 - lo) / Float(hi - lo) }
        }
        
        func display() {
            let scores = stats.map(\.score)
            let pairs = zip(scores, (0 ..< prototypes.count)).sorted(by: { $0.0 > $1.0 })
            for (score, index) in pairs {
                let strat = prototypes[index]
                let r = String(format: "%.2f", rank[index])
                print("\(strat) <\(strat.computeSignature())>: \(r) \(score) : \(stats[index].summary)")
            }
        }
        
        func topNormalized(_ defecting: Float, _ cooperating: Float) -> String {
            let scores = stats.map { $0.normalizedScore(defecting, cooperating) }
            return prototypes[scores.argmax].description
        }
        
        func normalResultTable() {
            for c in stride(from: 0.0, to: 1.0, by: 0.05) {
                for d in stride(from: 0.0, to: c, by: 0.05) {
                    let name = topNormalized(Float(d), Float(c))
                    print("\(d), \(c), \(name)")
                }
            }
        }
        
        var rankTable: [String: Float] {
            var result: [String: Float] = [:]
            for i in 0 ..< prototypes.count {
                result[prototypes[i].description] = rank[i]
            }
            return result
        }
        
        var averageScore: [String: Float] {
            var result: [String: Float] = [:]
            for i in 0 ..< prototypes.count {
                result[prototypes[i].description] = Float(stats[i].score) / Float(stats[i].count)
            }
            return result
        }
        
        var trimmed: Tournament {
            let list = prototypes.enumerated().compactMap { rank[$0.offset] > 0.0 ? $0.element : nil }
            return .init(prototypes: list)
        }
    }

    func tournament() {
        var tour = OneGameMemoryStrategy.unique26() //.redundant32()
        var ranks: [String: [Float]] = [:]
        var averages: [String: [Float]] = [:]
        while tour.prototypes.count > 4 {
            print(" ---- \(tour.prototypes.count)")
            tour.computeRanking()
            tour.display()
            tour.normalResultTable()
            if ranks.isEmpty {
                for (name, rank) in tour.rankTable {
                    ranks[name] = [rank, rank]
                }
                for (name, ave) in tour.averageScore {
                    averages[name] = [ave, ave]
                }
            } else {
                for (name, rank) in tour.rankTable {
                    if rank != 0.0 {
                        ranks[name] = ranks[name]! + [rank]
                    }
                }
                for (name, ave) in tour.averageScore {
                    averages[name] = averages[name]! + [ave]
                }
            }
            tour = tour.trimmed
        }
        print("name, start, round1, round2, round3")
        for (name, list) in ranks {
            let nums = list.map { String($0) }
            print("\"\(name)\", " + nums.joined(separator: ", "))
        }
        print("name, start, round1, round2, round3")
        for (name, list) in averages {
            let nums = list.map { String($0) }
            print("\"\(name)\", " + nums.joined(separator: ", "))
        }
    }
}

extension PDilemma.OneGameMemoryStrategy {
    init?(name desc: String) {
        let bits = desc.compactMap {
            switch $0 {
            case "0": return false
            case "1": return true
            default: return nil
            }
        }
        guard bits.count == 5 else { return nil }
        self.init(bits: bits)
    }
}

extension Array where Element == PDilemma.OneGame {
    var stats: PDilemma.Stats {
        .init(outcomes: map(\.outcome))
    }
}

extension Array where Element == Float {
    var argmax: Int {
        var curMax = -Float.infinity
        var index = -1
        for (i, value) in enumerated() {
            if value > curMax {
                curMax = value
                index = i
            }
        }
        return index
    }
}

extension Int {
    func binaryString(digits: Int) -> String {
        var value = self
        var result = ""
        for _ in 0 ..< digits {
            result = ((value & 1 == 1) ? "1" : "0") + result
            value = value / 2
        }
        return result
    }
}
