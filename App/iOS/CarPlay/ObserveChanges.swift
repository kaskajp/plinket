import Observation

/// Calls `onChange` with the current value, then again whenever the observed value changes to a different one.
@MainActor
func observeChanges<Value: Equatable & Sendable>(
    of value: @escaping @MainActor @Sendable () -> Value,
    onChange: @escaping @MainActor (Value) -> Void
) -> Task<Void, Never> {
    let initialValue = value()
    onChange(initialValue)
    return Task {
        var handledValue = initialValue
        for await currentValue in Observations(value) where currentValue != handledValue {
            handledValue = currentValue
            onChange(currentValue)
        }
    }
}
