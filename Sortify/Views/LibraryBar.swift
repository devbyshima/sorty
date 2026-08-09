import SwiftUI

/// The category chips and the search field, as one bar under the title.
///
/// Adapted from the `FTBar` sample by Balaji Venkatesh: a row of glass capsules
/// with a search that lives at the end of the row rather than in a bar of its
/// own. Collapsed it is a magnifying glass the width of a chip; tapped, it
/// expands to fill the row and the chips slide out of the way behind it, with a
/// grid button to bring them back.
///
/// It replaces `.searchable`, which put the field at the bottom of the screen,
/// a long way from the categories that do the same job.
struct LibraryBar: View {
    let filters: [PlaylistFilter]
    @Binding var selection: PlaylistFilter
    @Binding var searchText: String
    @Binding var isSearchExpanded: Bool
    /// Reported so the screen can give the whole row to the search field by
    /// standing the title down while typing.
    var onSearchActivated: (Bool) -> Void
    var count: (PlaylistFilter) -> Int

    @State private var viewSize: CGSize = .zero
    @FocusState private var isKeyboardActive: Bool

    /// Deliberately not `.snappy`. This is a slide rather than a settle, and a
    /// bouncing search field that overshoots its own edge reads as loose.
    private let animation: Animation = .interpolatingSpring(duration: 0.3, bounce: 0)

    /// One height for every capsule in the row, and one width for the round
    /// buttons, so the chips, the search field, the grid button and the clear
    /// button cannot drift apart. The two derived numbers below depend on
    /// these, which is the whole reason they are named rather than typed in
    /// four places.
    private let capsuleHeight: Double = 38
    private let roundWidth: Double = 60
    private let spacing: Double = 12
    private let horizontalPadding: Double = 16

    /// What the expanded field has to give up: the grid button, the gap before
    /// it, and the row's own margins.
    private var searchInset: Double { spacing + roundWidth + horizontalPadding * 2 }
    /// The clear button and the gap before it.
    private var clearInset: Double { capsuleHeight + spacing }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: spacing) {
                ForEach(filters) { filter in
                    chip(filter)
                }
                searchBar
            }
            .padding(.horizontal, horizontalPadding)
            // Slides the row left so the expanded field sits where the chips
            // were, rather than off the trailing edge.
            .visualEffect { [isSearchExpanded, viewSize] content, proxy in
                let rect = proxy.frame(in: .scrollView)
                let maxX = rect.maxX - viewSize.width
                return content.offset(x: isSearchExpanded ? -maxX : 0)
            }
        }
        .frame(height: capsuleHeight + 5)
        .scrollDisabled(isSearchExpanded)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .animation(animation, value: selection)
        .animation(animation, value: isKeyboardActive)
        .onChange(of: isKeyboardActive) { _, active in
            onSearchActivated(active)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { viewSize = $0 }
    }

    // MARK: - Chips

    @ViewBuilder
    private func chip(_ filter: PlaylistFilter) -> some View {
        let isSelected = selection == filter
        let isLast = filters.last == filter && isSearchExpanded

        ZStack {
            if isLast {
                // Where the last chip was, so the row has somewhere to put the
                // way back without adding a control that is otherwise idle.
                Image(systemName: "circle.grid.2x2.fill")
                    .frame(width: roundWidth, height: capsuleHeight)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEdge(in: .capsule)
                    .contentShape(.capsule)
                    .onTapGesture {
                        isKeyboardActive = false
                        withAnimation(animation) { isSearchExpanded = false }
                    }
                    .padding(.leading, spacing)
                    .accessibilityLabel("Show categories")
            } else {
                Text(filter.label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(height: capsuleHeight)
                    .foregroundStyle(isSelected ? SortifyTheme.onAccent : .primary)
                    .background(isSelected ? AnyShapeStyle(SortifyTheme.accent) : AnyShapeStyle(.clear), in: .capsule)
                    .glassEffect(.regular.interactive(!isSearchExpanded), in: .capsule)
                    // Same rule as the Arrangement chips: the selected one is
                    // filled with the accent and needs no stroke over it.
                    .glassEdge(in: .capsule, isEnabled: !isSelected)
                    .contentShape(.capsule)
                    .onTapGesture {
                        // Tapping the active chip clears back to All, so there
                        // is always a way out without hunting for the one
                        // labelled "All".
                        selection = isSelected ? .all : filter
                    }
                    .disabled(isSearchExpanded)
                    .accessibilityLabel(filter.label)
                    .accessibilityValue("\(count(filter)) playlists")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        let fitted = viewSize.width - searchInset

        return ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .frame(width: isSearchExpanded ? 40 : roundWidth)

                if isSearchExpanded {
                    TextField("Find a playlist", text: $searchText)
                        .focused($isKeyboardActive)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                }
            }
            .padding(.leading, isSearchExpanded ? 5 : 0)
            .padding(.trailing, isSearchExpanded ? 15 : 0)
            .frame(height: capsuleHeight)
            .clipShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEdge(in: .capsule)
            .contentShape(.capsule)
            .gesture(
                TapGesture().onEnded {
                    withAnimation(animation) { isSearchExpanded = true }
                },
                isEnabled: !isSearchExpanded
            )
            .zIndex(1)
            .padding(.trailing, isKeyboardActive ? clearInset : 0)
            .accessibilityLabel("Search playlists")

            Button {
                searchText = ""
                isKeyboardActive = false
            } label: {
                Image(systemName: "xmark")
                    .frame(width: capsuleHeight, height: capsuleHeight)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEdge(in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .opacity(isKeyboardActive ? 1 : 0)
            .zIndex(0)
            .accessibilityLabel("Clear search")
        }
        .frame(width: isSearchExpanded ? fitted : nil)
    }
}
