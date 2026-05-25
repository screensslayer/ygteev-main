//
//  PastorPlanService.swift
//  YGTeeV
//
//  Backs the pastor "Publish a Bible plan" flow. All writes go through
//  the pastor_* RPCs; XP/water are server-computed and never sent from
//  the client.
//

import Foundation
import SwiftUI
import Supabase

@MainActor
@Observable
final class PastorPlanService {
    static let shared = PastorPlanService()
    private let client = SupabaseManager.shared.client

    /// The plan the pastor is currently editing.
    var draft: BiblePlanDraft?

    /// Local in-flight blocks per day, keyed by dayNumber so autosaves can
    /// dedupe and merge.
    var blocksByDay: [Int: [Block]] = [:]

    /// All plans the pastor's group owns, newest first. Populated by
    /// `loadMyPlans(groupId:)` and consumed by the "All plans" list view.
    var myPlans: [PastorPlanSummary] = []

    /// Autosave debounce.
    private var saveTasks: [Int: Task<Void, Never>] = [:]
    private let saveDelayNs: UInt64 = 500_000_000

    private init() {}

    // MARK: - Plan list

    /// All plans the caller is pastor of, across every group, drafts first.
    /// Backed by `pastor_list_my_plans()` which already orders & RLS-scopes.
    func listMyPlans() async {
        do {
            let rows: [PastorPlanSummary] = try await client
                .rpc("pastor_list_my_plans")
                .execute()
                .value
            await MainActor.run { self.myPlans = rows }
        } catch {
            print("[PastorPlanService] listMyPlans:", error)
        }
    }

    /// Hard-delete a draft (or any plan the caller owns). Server enforces
    /// authorization; we just shell out and refetch the list on success.
    func deletePlan(planId: UUID) async throws {
        struct Params: Encodable { let _plan_id: String }
        _ = try await client
            .rpc("pastor_delete_plan",
                 params: Params(_plan_id: planId.uuidString.lowercased()))
            .execute()
    }

    /// Hydrate `blocksByDay` from the server for an existing plan. Used
    /// when the pastor opens an existing draft from the list view. Per the
    /// v1 contract, blocks live inside the `sections` jsonb column (under
    /// the `blocks` key), not as a top-level column.
    func loadDaysIntoCache(planId: UUID) async {
        struct SectionsBlob: Decodable { let blocks: [Block]? }
        struct Row: Decodable {
            let day_number: Int
            let sections: SectionsBlob?
        }
        do {
            let rows: [Row] = try await client
                .from("bible_plan_days")
                .select("day_number, sections")
                .eq("plan_id", value: planId.uuidString.lowercased())
                .order("day_number", ascending: true)
                .execute()
                .value
            await MainActor.run {
                var cache: [Int: [Block]] = [:]
                for row in rows { cache[row.day_number] = row.sections?.blocks ?? [] }
                self.blocksByDay = cache
            }
        } catch {
            print("[PastorPlanService] loadDaysIntoCache (returning empty cache):", error)
            await MainActor.run { self.blocksByDay = [:] }
        }
    }

    /// Fresh read of a single day from the server. The day builder calls
    /// this on tab switch / re-entry so local memory never overwrites a
    /// previously-saved server state.
    func loadDay(planId: UUID, dayNumber: Int) async -> (title: String, scriptureRef: String, blocks: [Block])? {
        struct SectionsBlob: Decodable { let blocks: [Block]? }
        struct Row: Decodable {
            let title: String?
            let scripture_reference: String?
            let sections: SectionsBlob?
        }
        do {
            let row: Row = try await client
                .from("bible_plan_days")
                .select("title, scripture_reference, sections")
                .eq("plan_id", value: planId.uuidString.lowercased())
                .eq("day_number", value: dayNumber)
                .single()
                .execute()
                .value
            let result = (
                title: row.title ?? "",
                scriptureRef: row.scripture_reference ?? "",
                blocks: row.sections?.blocks ?? []
            )
            await MainActor.run { self.blocksByDay[dayNumber] = result.blocks }
            return result
        } catch {
            // No row yet for this day_number is the normal case for a new plan.
            print("[PastorPlanService] loadDay plan=\(planId) day=\(dayNumber):", error)
            return nil
        }
    }

    // MARK: - Plan basics

    /// Create a plan. `groupId` is the canonical owner; pass extras the
    /// same plan should also be visible in via `additionalGroupIds`.
    /// Empty array (the default) means "single-group plan" — backwards
    /// compatible with all existing callers.
    func createPlan(groupId: UUID,
                    title: String,
                    days: Int,
                    gradientIdx: Int,
                    additionalGroupIds: [UUID] = []) async throws -> UUID {
        var body: [String: AnyJSON] = [
            "_group_id":     .string(groupId.uuidString.lowercased()),
            "_title":        .string(title.trimmingCharacters(in: .whitespacesAndNewlines)),
            "_days":         .integer(days),
            "_gradient_idx": .integer(gradientIdx),
        ]
        // Send only when the caller actually passed extras. The RPC's
        // 6th param defaults to NULL on the server, which means "single
        // group" — same result as omitting.
        if !additionalGroupIds.isEmpty {
            body["_additional_group_ids"] = .array(
                additionalGroupIds.map { .string($0.uuidString.lowercased()) }
            )
        }
        let id: UUID = try await client
            .rpc("pastor_create_plan", params: body)
            .execute()
            .value
        return id
    }

    func updateBasics(planId: UUID,
                      title: String? = nil,
                      days: Int? = nil,
                      headerKind: HeaderKind? = nil,
                      headerImageURL: String? = nil,
                      gradientIdx: Int? = nil,
                      visibility: PlanVisibility? = nil,
                      groupId: UUID? = nil,
                      additionalGroupIds: [UUID]? = nil) async throws {
        var body: [String: AnyJSON] = ["_plan_id": .string(planId.uuidString.lowercased())]
        if let title          { body["_title"]            = .string(title) }
        if let days           { body["_days"]             = .integer(days) }
        if let headerKind     { body["_header_kind"]      = .string(headerKind.rawValue) }
        if let headerImageURL { body["_header_image_url"] = .string(headerImageURL) }
        if let gradientIdx    { body["_gradient_idx"]     = .integer(gradientIdx) }
        if let visibility     { body["_visibility"]       = .string(visibility.rawValue) }
        if let groupId        { body["_group_id"]         = .string(groupId.uuidString.lowercased()) }
        // `nil` = leave column unchanged; `[]` = clear all extras.
        if let additionalGroupIds {
            body["_additional_group_ids"] = .array(
                additionalGroupIds.map { .string($0.uuidString.lowercased()) }
            )
        }
        _ = try await client
            .rpc("pastor_update_plan_basics", params: body)
            .execute()
    }

    // MARK: - Pastor groups

    /// All youth groups the caller is pastor of, used to populate the
    /// group picker on the plan-setup screen. Hidden when there's only one.
    func loadMyPastorGroups() async -> [PastorGroup] {
        do {
            let groups: [PastorGroup] = try await client
                .rpc("pastor_my_groups")
                .execute()
                .value
            return groups
        } catch {
            print("[PastorPlanService] pastor_my_groups failed:", error)
            return []
        }
    }

    // MARK: - Day upsert (idempotent on (plan_id, day_number))

    func upsertDay(planId: UUID,
                   dayNumber: Int,
                   title: String,
                   scriptureRef: String,
                   blocks: [Block]) async throws {
        struct Params: Encodable {
            let _plan_id: String
            let _day_number: Int
            let _title: String
            let _scripture_reference: String
            let _blocks: AnyJSON
        }

        // Encode blocks → AnyJSON array via Data → JSONSerialization → AnyJSON.
        let blocksData = try JSONEncoder().encode(blocks)
        let blocksAny = try Self.anyJSON(from: blocksData)

        print("[upsertDay] sending: plan=\(planId.uuidString.lowercased()) day=\(dayNumber) blocks=\(blocks.count) title=\"\(title)\" ref=\"\(scriptureRef)\"")
        do {
            // Do NOT decode the return — the RPC may be void; we only care
            // that the call succeeds. Previously this used `.value` to a UUID
            // and silently failed every save when the RPC didn't return one.
            _ = try await client
                .rpc("pastor_upsert_day", params: Params(
                    _plan_id:             planId.uuidString.lowercased(),
                    _day_number:          dayNumber,
                    _title:               title.trimmingCharacters(in: .whitespaces),
                    _scripture_reference: scriptureRef.trimmingCharacters(in: .whitespaces),
                    _blocks:              blocksAny
                ))
                .execute()
            print("[upsertDay] saved")
        } catch {
            print("[upsertDay] failed:", error)
            throw error
        }
    }

    // MARK: - Publish / archive

    /// Server validates: every day must have ≥ 1 block. If the error message
    /// contains "day(s) with no blocks", parse out the count for inline UI.
    func publish(planId: UUID) async throws {
        struct Params: Encodable { let _plan_id: String }
        _ = try await client
            .rpc("pastor_publish_plan",
                 params: Params(_plan_id: planId.uuidString.lowercased()))
            .execute()
    }

    func archive(planId: UUID) async throws {
        struct Params: Encodable { let _plan_id: String }
        _ = try await client
            .rpc("pastor_archive_plan",
                 params: Params(_plan_id: planId.uuidString.lowercased()))
            .execute()
    }

    // MARK: - Plan video uploads (Mux Direct Upload)

    /// Handle returned by the `pastor-create-plan-video-upload` Edge
    /// Function — the one-time Mux upload URL the iOS app PUTs the file
    /// to, plus the freshly-inserted `videos` row id to track status.
    struct PlanVideoUploadHandle: Decodable {
        let uploadUrl: String
        let muxUploadId: String
        let videoId: UUID
        enum CodingKeys: String, CodingKey {
            case uploadUrl   = "upload_url"
            case muxUploadId = "mux_upload_id"
            case videoId     = "video_id"
        }
    }

    /// Asks the Edge Function for a one-time Mux upload URL bound to a
    /// specific plan day + block. The function inserts the `videos` row
    /// with `scope='plan'` and `status='uploading'` (we have no insert
    /// policy from the client, so this is the only path).
    func createPlanVideoUpload(planId: UUID,
                               dayId: UUID,
                               blockId: UUID,
                               title: String?) async throws -> PlanVideoUploadHandle {
        struct Params: Encodable {
            let plan_id: UUID
            let plan_day_id: UUID
            let plan_block_id: String
            let title: String?
        }
        return try await client.functions.invoke(
            "pastor-create-plan-video-upload",
            options: FunctionInvokeOptions(body: Params(
                plan_id: planId,
                plan_day_id: dayId,
                plan_block_id: blockId.uuidString,
                title: (title?.isEmpty == true) ? nil : title
            ))
        )
    }

    /// Streams `fileURL` (a local mov/mp4) to Mux via PUT. Calls
    /// `progress` with 0…1 as bytes go out. Throws on non-2xx response.
    func uploadVideoFile(_ fileURL: URL,
                         to uploadURL: URL,
                         progress: @escaping @Sendable (Double) -> Void) async throws {
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "PUT"
        req.setValue("video/mp4", forHTTPHeaderField: "Content-Type")

        let delegate = MuxUploadProgressDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (_, response) = try await session.upload(for: req, fromFile: fileURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(
                domain: "MuxUpload",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Mux rejected the upload (HTTP \(http.statusCode))."]
            )
        }
    }

    /// Single row pulled from `videos` while we poll for Mux to finish
    /// encoding. Pastors can read at any status; members only when
    /// `status='ready'` (RLS enforced server-side).
    struct PlanVideoRow: Decodable, Hashable {
        let id: UUID
        let status: String           // "uploading" | "processing" | "ready" | "errored"
        let muxPlaybackId: String?
        let durationSec: Double?
        let aspectRatio: String?

        enum CodingKeys: String, CodingKey {
            case id, status
            case muxPlaybackId = "mux_playback_id"
            case durationSec   = "duration_sec"
            case aspectRatio   = "aspect_ratio"
        }
    }

    /// One-shot fetch of the current state of a `videos` row by id.
    /// Returns nil when RLS hides the row or no row matches.
    /// (We fetch as an array + take first to dodge `.maybeSingle()`,
    /// which isn't available on this version of the Swift SDK.)
    func fetchPlanVideo(id: UUID) async throws -> PlanVideoRow? {
        let rows: [PlanVideoRow] = try await client
            .from("videos")
            .select("id, status, mux_playback_id, duration_sec, aspect_ratio")
            .eq("id", value: id.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Look up the `bible_plan_days.id` for a given (plan, day_number)
    /// pair so we can pass it to the upload Edge Function. The day row
    /// is created on the first upsert; if it doesn't exist yet, this
    /// returns `nil` and the caller is responsible for committing the
    /// day's blocks first.
    func fetchPlanDayId(planId: UUID, dayNumber: Int) async throws -> UUID? {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("bible_plan_days")
            .select("id")
            .eq("plan_id", value: planId.uuidString.lowercased())
            .eq("day_number", value: dayNumber)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    // MARK: - Header image upload

    func uploadHeaderImage(planId: UUID, jpegData: Data) async throws -> String {
        let filename = "header-\(Int(Date().timeIntervalSince1970)).jpg"
        let path = "\(planId.uuidString.lowercased())/\(filename)"

        try await client.storage
            .from("bible-plan-headers")
            .upload(path, data: jpegData, options: .init(contentType: "image/jpeg"))

        return try client.storage
            .from("bible-plan-headers")
            .getPublicURL(path: path)
            .absoluteString
    }

    // MARK: - AI assist (Edge Function)

    struct Suggestion: Identifiable, Decodable, Hashable {
        let body: String

        var id: String { body }

        enum CodingKeys: String, CodingKey { case body }
    }

    func aiAssist(reference: String,
                  planTitle: String? = nil,
                  currentDraft: String? = nil) async throws -> [Suggestion] {
        struct Body: Encodable {
            let reference: String
            let plan_title: String?
            let current_draft: String?
        }
        struct Response: Decodable {
            let suggestions: [Suggestion]
        }

        let body = Body(reference: reference, plan_title: planTitle, current_draft: currentDraft)
        let resp: Response = try await client.functions.invoke(
            "ai-commentary-assist",
            options: FunctionInvokeOptions(body: body)
        )
        return resp.suggestions
    }

    // MARK: - Autosave (debounced)

    /// Latest snapshot per day, used by `flushPending` to commit the freshest
    /// state when navigation pre-empts the debounce timer.
    private var pendingPayloads: [Int: (planId: UUID, title: String, ref: String, blocks: [Block])] = [:]

    /// Last autosave error per day. Surfaced in the day builder UI so a
    /// failing RPC isn't invisible.
    var lastAutosaveError: String?

    /// Mutate the local blocks for a day and schedule an autosave. Multiple
    /// calls within ~500ms coalesce into one upsert.
    func updateBlocks(forDay dayNumber: Int, blocks: [Block], in plan: BiblePlanDraft, dayTitle: String, scriptureRef: String) {
        print("[updateBlocks] day=\(dayNumber) plan=\(plan.id.uuidString.lowercased()) blocks=\(blocks.count) title=\"\(dayTitle)\" ref=\"\(scriptureRef)\"")
        blocksByDay[dayNumber] = blocks
        pendingPayloads[dayNumber] = (plan.id, dayTitle, scriptureRef, blocks)
        scheduleAutosave(forDay: dayNumber)
    }

    private func scheduleAutosave(forDay dayNumber: Int) {
        print("[scheduleAutosave] day=\(dayNumber) (debounce 500ms)")
        saveTasks[dayNumber]?.cancel()
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled {
                print("[scheduleAutosave] day=\(dayNumber) cancelled before fire")
                return
            }
            print("[scheduleAutosave] day=\(dayNumber) firing")
            await self?.commitPending(forDay: dayNumber)
        }
        saveTasks[dayNumber] = task
    }

    private func commitPending(forDay dayNumber: Int) async {
        guard let payload = pendingPayloads[dayNumber] else {
            print("[commitPending] day=\(dayNumber) — no pending payload")
            return
        }
        print("[commitPending] day=\(dayNumber) committing blocks=\(payload.blocks.count)")
        do {
            try await upsertDay(
                planId: payload.planId,
                dayNumber: dayNumber,
                title: payload.title,
                scriptureRef: payload.ref,
                blocks: payload.blocks
            )
            pendingPayloads[dayNumber] = nil
            lastAutosaveError = nil
        } catch {
            // upsertDay already logged the error; leave the payload pending
            // so a later flush can retry, and surface the message to the UI.
            lastAutosaveError = error.localizedDescription
            print("[commitPending] day=\(dayNumber) failed:", error)
        }
    }

    /// Force any pending debounced save for `dayNumber` to fire immediately.
    /// Call when the day view disappears so the upsert isn't stranded.
    func flushPending(forDay dayNumber: Int) async {
        saveTasks[dayNumber]?.cancel()
        saveTasks[dayNumber] = nil
        await commitPending(forDay: dayNumber)
    }

    /// Flush every day's pending save. Call on app-background / cold-exit
    /// scenarios so nothing in flight is lost.
    func flushAllPending() async {
        let days = Array(pendingPayloads.keys)
        for day in days { await flushPending(forDay: day) }
    }

    // MARK: - Lifecycle

    func reset() {
        draft = nil
        blocksByDay = [:]
        pendingPayloads = [:]
        for task in saveTasks.values { task.cancel() }
        saveTasks.removeAll()
    }

    // MARK: - Helpers

    /// Convert raw JSON `Data` into `AnyJSON`. Used to pass arbitrary
    /// `jsonb` arrays to RPCs without enumerating every block-payload shape.
    private static func anyJSON(from data: Data) throws -> AnyJSON {
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return try anyJSON(fromAny: json)
    }

    private static func anyJSON(fromAny value: Any) throws -> AnyJSON {
        if value is NSNull { return .null }
        // NSNumber bridges to Bool, Int, AND Double for the same instance,
        // so `value as? Bool` matches NSNumber(0)/(1) and silently turns
        // `correct_index: 0` into `false`. Disambiguate via CoreFoundation:
        // booleans are CFBooleanRef internally and have a distinct type ID.
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return .bool(n.boolValue)
            }
            // objCType: "c"/"i"/"l"/"q" etc. are integer encodings; "f"/"d" are floats.
            let type = String(cString: n.objCType)
            if ["f", "d"].contains(type) {
                return .double(n.doubleValue)
            }
            return .integer(n.intValue)
        }
        if let s = value as? String { return .string(s) }
        if let arr = value as? [Any] {
            return .array(try arr.map(anyJSON(fromAny:)))
        }
        if let dict = value as? [String: Any] {
            var out: [String: AnyJSON] = [:]
            for (k, v) in dict { out[k] = try anyJSON(fromAny: v) }
            return .object(out)
        }
        throw NSError(domain: "PastorPlanService", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Unsupported JSON value: \(type(of: value))"])
    }
}

// MARK: - Mux upload progress

/// Bridges URLSession's upload-task progress callbacks into a SwiftUI-
/// safe closure that the VideoEditorView uses to drive the progress bar.
/// Owned by `uploadVideoFile` for the duration of a single upload.
private final class MuxUploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let progress: @Sendable (Double) -> Void

    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progress(min(max(fraction, 0), 1))
    }
}
