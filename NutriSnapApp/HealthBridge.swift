//  HealthBridge.swift — Ponte Apple Saúde (HealthKit) → site do NutriSnap.
//  A balança (Cubitt Health) grava peso/gordura/IMC no Apple Saúde; aqui o
//  app LÊ esse histórico (só leitura) e entrega ao JS via window.nutriHealth().
//
//  JS → nativo:  webkit.messageHandlers.health.postMessage('connect' | 'sync')
//    'connect' = pede permissão (1ª vez) e lê
//    'sync'    = só lê se já foi conectado antes (usado ao abrir/voltar ao app)
//  nativo → JS:  window.nutriHealth({ ok, amostras:[{k,t,v,src}], erro })
//    k = peso (kg) | gordura (%) | imc | magra (kg)

import Foundation
import HealthKit
import WebKit

final class HealthBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private let store = HKHealthStore()
    private let flagConectado = "hk_conectado"

    private let tipos: [(chave: String, id: HKQuantityTypeIdentifier, unidade: HKUnit, fator: Double)] = [
        ("peso",    .bodyMass,          .gramUnit(with: .kilo), 1),
        ("gordura", .bodyFatPercentage, .percent(),             100),
        ("imc",     .bodyMassIndex,     .count(),               1),
        ("magra",   .leanBodyMass,      .gramUnit(with: .kilo), 1),
    ]

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "health" else { return }
        sync(pedirPermissao: (message.body as? String) == "connect")
    }

    func sync(pedirPermissao: Bool) {
        guard HKHealthStore.isHealthDataAvailable() else {
            if pedirPermissao { enviar(erro: "Apple Saúde não disponível neste aparelho.") }
            return
        }
        if !pedirPermissao && !UserDefaults.standard.bool(forKey: flagConectado) { return }

        let leitura = Set<HKObjectType>(tipos.compactMap { HKObjectType.quantityType(forIdentifier: $0.id) as HKObjectType? })
        store.requestAuthorization(toShare: nil, read: leitura) { [weak self] ok, err in
            guard let self else { return }
            if ok {
                UserDefaults.standard.set(true, forKey: self.flagConectado)
                self.ler()
            } else {
                self.enviar(erro: err?.localizedDescription ?? "Permissão negada.")
            }
        }
    }

    private func ler() {
        let desde = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        let pred = HKQuery.predicateForSamples(withStart: desde, end: nil)
        let ordem = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let iso = ISO8601DateFormatter()
        let grupo = DispatchGroup()
        let fila = DispatchQueue(label: "nutrisnap.health")
        var amostras: [[String: Any]] = []

        for t in tipos {
            guard let tipo = HKQuantityType.quantityType(forIdentifier: t.id) else { continue }
            grupo.enter()
            let q = HKSampleQuery(sampleType: tipo, predicate: pred, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: ordem) { _, res, _ in
                let lote = (res as? [HKQuantitySample] ?? []).map { s -> [String: Any] in
                    ["k": t.chave,
                     "t": iso.string(from: s.startDate),
                     "v": (s.quantity.doubleValue(for: t.unidade) * t.fator * 100).rounded() / 100,
                     "src": s.sourceRevision.source.name]
                }
                fila.sync { amostras.append(contentsOf: lote) }
                grupo.leave()
            }
            store.execute(q)
        }
        grupo.notify(queue: .main) { [weak self] in
            self?.chamarJS(["ok": true, "amostras": amostras])
        }
    }

    private func enviar(erro: String) {
        DispatchQueue.main.async { self.chamarJS(["ok": false, "erro": erro]) }
    }

    private func chamarJS(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.nutriHealth && window.nutriHealth(\(json))")
    }
}
