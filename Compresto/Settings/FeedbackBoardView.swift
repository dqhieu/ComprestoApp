//
//  FeedbackBoardView.swift
//  Compresto
//
//  Created by Hieu Dinh on 8/2/25.
//

import SwiftUI
import Supabase

struct FeedbackBoardView: View {

  @State private var feedbacks: [Feedback] = []
  @State private var isLoading = false
  @State private var isRefreshing = false
  @State private var errorMessage: String?
  @State private var upvotingRequests: [String] = []
  @AppStorage("upvotedRequests") private var upvotedRequests: [String] = []
  @State private var showAddFeedback = false

  @State private var feedbackText = ""

  var body: some View {
    NavigationStack {
      content
        .toolbar {
          if #available(macOS 26, *) {
            ToolbarSpacer(.flexible)
          }
          ToolbarItemGroup(placement: .automatic) {
            Button {
              Task {
                isRefreshing = true
                await fetchFeedbacks(setLoading: false)
                isRefreshing = false
              }
            } label: {
              Image(systemName: "arrow.clockwise")
            }
            Button {
              showAddFeedback = true
            } label: {
              Image(systemName: "plus")
            }
          }
        }
        .overlay {
          if isRefreshing {
            ZStack {
              Color.secondary.opacity(0.3)
              ProgressView()
            }
          }
        }
        .sheet(isPresented: $showAddFeedback) {
          NewFeedbackView {
            Task {
              await fetchFeedbacks(setLoading: false)
            }
          }
        }
    }
    .task {
      await fetchFeedbacks(setLoading: true)
    }
  }

  @ViewBuilder
  private var content: some View {
    if isLoading {
      ProgressView("Loading requests...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let errorMessage = errorMessage {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 48, height: 48)
          .foregroundStyle(.orange)

        Text("Error")
          .font(.title2)
          .fontWeight(.bold)

        Text(errorMessage)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button("Try Again") {
          Task {
            await fetchFeedbacks(setLoading: true)
          }
        }
        .padding(.horizontal, 48)
      }
      .padding()
    } else {
      ScrollView {
        HStack(alignment: .top, spacing: 8) {
          LazyVStack(spacing: 8) {
            ForEach(sortedFeedbacks.enumerated().filter { index, _ in index % 2 == 0 }.map { $0.element }, id: \.id) { request in
              FeedbackRowView(
                request: request,
                isUpvoted: upvotedRequests.contains(request.id),
                isUpvoting: upvotingRequests.contains(request.id),
                onUpvote: {
                  toggleUpvote(for: request)
                }
                , onStatusChange: { status in
#if DEBUG
                  updateStatus(for: request, to: status)
#endif
                }

              )
            }
          }
          LazyVStack(spacing: 8) {
            ForEach(sortedFeedbacks.enumerated().filter { index, _ in index % 2 != 0 }.map { $0.element }, id: \.id) { request in
              FeedbackRowView(
                request: request,
                isUpvoted: upvotedRequests.contains(request.id),
                isUpvoting: upvotingRequests.contains(request.id),
                onUpvote: {
                  toggleUpvote(for: request)
                }
                , onStatusChange: { status in
#if DEBUG
                  updateStatus(for: request, to: status)
#endif
                }

              )
            }
          }
        }
        .padding(8)
      }
      .scrollIndicators(.hidden)
      .navigationTitle("Feedback Board")
    }
  }

  private var sortedFeedbacks: [Feedback] {
    feedbacks.sorted { lhs, rhs in
      // First, prioritize by status - "done" requests go to bottom
      let lhsIsDone = lhs.status == RequestStatus.done.rawValue
      let rhsIsDone = rhs.status == RequestStatus.done.rawValue

      if lhsIsDone != rhsIsDone {
        return !lhsIsDone // Non-done requests come first
      }

      // Within same status group, sort by upvotes
      if lhs.upvotes != rhs.upvotes {
        return lhs.upvotes > rhs.upvotes
      }

      // Finally, sort by creation date
      return lhs.created_at > rhs.created_at
    }
  }

  private func fetchFeedbacks(setLoading: Bool) async {
    if setLoading {
      isLoading = true
    }
    errorMessage = nil

    do {
      let requests: [Feedback] = try await client
        .from("feedback_board")
        .select()
        .execute()
        .value
      feedbacks = requests
    } catch {
      errorMessage = "\(error)"
    }
    isLoading = false
  }

  #if DEBUG
  private func updateStatus(for request: Feedback, to status: RequestStatus) {
    Task {
      do {
        try await client
          .from("feedback_board")
          .update(["status": status.rawValue])
          .eq("id", value: request.id)
          .execute()

        await MainActor.run {
          if let index = feedbacks.firstIndex(where: { $0.id == request.id }) {
            withAnimation {
              feedbacks[index].status = status.rawValue
            }
          }
        }
      } catch {
        // Silently fail, matching existing pattern
      }
    }
  }
  #endif

  private func toggleUpvote(for request: Feedback) {
    withAnimation {
      upvotingRequests.append(request.id)
    }
    Task {
      do {
        await fetchFeedbacks(setLoading: false)

        let isCurrentlyUpvoted = upvotedRequests.contains(request.id)
        let currentUpvotes = feedbacks.first(where: { $0.id == request.id })?.upvotes ?? 0
        var newUpvotes = isCurrentlyUpvoted ? currentUpvotes - 1 : currentUpvotes + 1
        if newUpvotes < 0 {
          newUpvotes = 0
        }

        try await client
          .from("feedback_board")
          .update(["upvotes": newUpvotes])
          .eq("id", value: request.id)
          .execute()

        await MainActor.run {
          if let index = feedbacks.firstIndex(where: { $0.id == request.id }) {
            withAnimation {
              feedbacks[index].upvotes = newUpvotes
            }
          }
          var updatedUpvotedRequests = upvotedRequests
          if isCurrentlyUpvoted {
            updatedUpvotedRequests.removeAll(where: { $0 == request.id })
          } else {
            updatedUpvotedRequests.append(request.id)
          }
          upvotedRequests = updatedUpvotedRequests
        }
      } catch {

      }
      await MainActor.run {
        withAnimation {
          upvotingRequests.removeAll(where: { $0 == request.id })
        }
      }
    }
  }
}

struct FeedbackRowView: View {
  let request: Feedback
  let isUpvoted: Bool
  var isUpvoting: Bool
  let onUpvote: () -> Void
  var onStatusChange: ((RequestStatus) -> Void)?
  #if DEBUG
  @State private var showStatusPicker = false
  #endif
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        Text(request.content)
          .font(.body)
          .multilineTextAlignment(.leading)
          .textSelection(.enabled)
        Spacer()
        Button(action: {
          onUpvote()
        }) {
          VStack(spacing: 4) {
            if isUpvoting {
              ProgressView()
                .controlSize(.small)
                .frame(width: 24, height: 24)
                .transition(.asymmetric(insertion: .scale(scale: 0.5).combined(with: .opacity), removal: .scale(scale: 0.5).combined(with: .opacity)))
            } else {
              Image(systemName: buttonIcon)
                .frame(width: 24, height: 24)
                .fontWeight(.semibold)
                .transition(.asymmetric(insertion: .scale(scale: 0.5).combined(with: .opacity), removal: .scale(scale: 0.5).combined(with: .opacity)))
            }

            Text("\(request.upvotes)")
              .font(.caption)
              .fontWeight(.medium)
              .contentTransition(.numericText())
          }
          .foregroundStyle(buttonColor)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(buttonBackgroundColor)
              .overlay {
                RoundedRectangle(cornerRadius: 12)
                  .stroke(buttonBorderColor, lineWidth: isUpvoted ? 1.5 : 0)
              }
          )
          .animation(.default, value: isUpvoted)
        }
        .buttonStyle(.plain)
        .disabled(isUpvoting || !allowsVoting)
      }
      HStack {
        Text(formatDate(request.created_at))
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()
        #if DEBUG
        statusBadge
          .onTapGesture { showStatusPicker.toggle() }
          .popover(isPresented: $showStatusPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(RequestStatus.allCases, id: \.self) { status in
                Button {
                  onStatusChange?(status)
                  showStatusPicker = false
                } label: {
                  HStack(spacing: 8) {
                    Circle()
                      .fill(status.color)
                      .frame(width: 8, height: 8)
                    Text(status.displayText)
                      .font(.caption)
                    Spacer()
                    if request.status == status.rawValue {
                      Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    }
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 4)
            .frame(width: 150)
          }
        #else
        statusBadge
        #endif
      }
    }
    .padding(16)
    .glassCard()
  }

  private var statusBadge: some View {
    Text(RequestStatus(rawValue: request.status)?.displayText ?? "Unknown")
      .font(.caption)
      .fontWeight(.medium)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(statusColor.opacity(0.2))
      .foregroundStyle(statusColor)
      .clipShape(.capsule)
  }

  private var allowsVoting: Bool {
    let status = RequestStatus(rawValue: request.status)
    return status != .done && status != .rejected
  }

  private var buttonIcon: String {
    if isUpvoted {
      return "triangleshape.fill"
    } else {
      return "triangleshape"
    }
  }

  private var buttonColor: Color {
    if isUpvoted {
      return .blue
    } else if !allowsVoting {
      return .secondary
    } else {
      return .primary
    }
  }

  private var buttonBackgroundColor: Color {
    if isUpvoted {
      return .blue.opacity(0.1)
    } else if !allowsVoting {
      return colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.97, green: 0.97, blue: 0.97)
    } else {
      return colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.95, green: 0.95, blue: 0.95)
    }
  }

  private var buttonBorderColor: Color {
    return isUpvoted ? .blue.opacity(0.3) : .clear
  }

  private var statusColor: Color {
    RequestStatus(rawValue: request.status)?.color ?? .gray
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

struct NewFeedbackView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) var colorScheme
  @AppStorage("upvotedRequests") private var upvotedRequests: [String] = []
  @State private var requestText = ""
  @State private var isSubmitting = false
  @State private var showingSuccessAlert = false
  @State private var errorMessage: String?
  let onRequestSubmitted: () -> Void

  // Validation constants
  private let minWordCount = 5

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("New Feedback")
            .font(.headline)
          Spacer()
          Button("Close") {
            dismiss()
          }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
      }


      VStack(alignment: .leading, spacing: 8) {
        Text("Describe your feedback")
          .font(.headline)
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("Tell us what feature you'd like to see in the app. Be as detailed as possible.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        ZStack(alignment: .topLeading) {

          RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.98, green: 0.98, blue: 0.98))
            .overlay {
              RoundedRectangle(cornerRadius: 12)
                .stroke(validationBorderColor, lineWidth: 1)
            }

          TextEditor(text: $requestText)
            .padding(12)
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .disabled(isSubmitting)

          if requestText.isEmpty {
            Text("Example: I'd like to batch compress images and videos together...")
              .foregroundStyle(.secondary)
              .padding(12)
              .padding(.leading, 3)
              .allowsHitTesting(false)
          }
        }
        .frame(minHeight: 120)


        // Validation feedback
        Text(validationMessage ?? "Please write at least \(minWordCount) words")
          .font(.caption)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .opacity(validationMessage == nil ? 0 : 1)
      }
      .padding()
      Button {
        submitRequest()
      } label: {
        HStack {
          if isSubmitting {
            ProgressView()
              .controlSize(.mini)
          }
          Text(isSubmitting ? "Submitting..." : "Submit Feedback")
            .fontWeight(.semibold)
        }
      }
      .buttonStyle(NiceButtonStyle())
      .disabled(!isValidRequest || isSubmitting)
      .padding(.bottom)
    }
    .frame(minWidth: 600)
    .alert("Request Submitted!", isPresented: $showingSuccessAlert) {
      Button("OK") {
        onRequestSubmitted()
        dismiss()
      }
    } message: {
      Text("Thank you for your feedback! Your feature request has been submitted and will be reviewed.")
    }
    .alert("Error", isPresented: .constant(errorMessage != nil)) {
      Button("OK") {
        errorMessage = nil
      }
    } message: {
      if let errorMessage = errorMessage {
        Text(String(Array(errorMessage).prefix(300)))
      }
    }
    .fontDesign(.rounded)
  }

  // MARK: - Validation Properties

  private var trimmedText: String {
    requestText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isValidRequest: Bool {
    let text = trimmedText
    return !text.isEmpty && wordCount(in: text) >= minWordCount
  }

  private var validationMessage: String? {
    let text = trimmedText

    if text.isEmpty {
      return nil
    }

    let currentWordCount = wordCount(in: text)
    if currentWordCount < minWordCount {
      return "Please write at least \(minWordCount) words (\(currentWordCount)/\(minWordCount))"
    }

    return nil
  }

  private var validationBorderColor: Color {
    if let _ = validationMessage {
      return .red.opacity(0.5)
    } else {
      return Color.primary.opacity(0.1)
    }
  }

  // MARK: - Validation Methods

  private func wordCount(in text: String) -> Int {
    let words = text.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
    return words.count
  }

  private func submitRequest() {
    let content = trimmedText
    guard !content.isEmpty else { return }

    isSubmitting = true

    Task {
      do {
        let newRequest = Feedback(
          id: UUID().uuidString,
          created_at: Date.now,
          content: content,
          upvotes: 1,
          status: RequestStatus.pending.rawValue,
          user_email: LicenseManager.shared.customerEmail
        )

        try await client
          .from("feedback_board")
          .insert(newRequest)
          .execute()

        await MainActor.run {
          upvotedRequests.append(newRequest.id)
          isSubmitting = false
          showingSuccessAlert = true
        }
      } catch {
        await MainActor.run {
          isSubmitting = false
          errorMessage = "Failed to submit request. Please try again.\n\(error)"
        }
      }
    }
  }
}
