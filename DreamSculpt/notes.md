# Rahul's running notes

### 3/21/2026
Goal for today:
    - understand the fundamental UI building blocks
    - understand declarative vs imperative 
    - understand the View protocol
        - lifecycle of a view
    - SwiftUI vs UIKit
    - Stacks: VStack, HStack, VStack
        - How space is allocated to child elements
    - @State and @Binding
    - what the fuck is a coodinator

Fundamental UI object is a View()
    - required property is body - defines the content and behavior of the view
    - Struct myView: View {
        var body: some View {
            Text("hello world")
        }
    }
        - init: gets called when swiftUI recreates the view
        - body: gets called every time a state that the view depends on changes
            - Lifecycle of a view:
                - 1. init()
                    - called when the view is recreated
                - 2. body()
                    - called when a state varible changes
                    - child views initialized inside body() are recreated, and their init() is called
                    - state variables persists across body() calls (view updates)
                - 3. the old and new view hierarchies are diffed. 
                - 4. Only changed views are re-rendered
                - 5. whenever state changes, restart from step 2
        - frame: Places the view in an invisible container of the specified size
            - useful for views that dont have intrinsic size, such as Color() or Rectangle()
            - setting maxHeight or maxWidth makes the container occupy as much space as possible along that axis

SwiftUI is declaritive, UIKit is imperative
    - declarative: outline the final state, framework abstracts away construction of that state
    - imperative: specify the exact process by which that state is constructed

VStack: Vertically organize content from top to bottom
    - use Spacer() to occupy vertical space
    - Flexible and Rigid elements interact to determine space allocation:
        - Rigid elements get the space they need, remaining is divided among flexible elements
HStack: Horizontally organize content from left to right
ZStack: Stack UI elements from base to top

@State: persists a value, usually representing some local state, across View recreations
@Binding: superset of state: Use when said state variable needs to be updateable from the child view
