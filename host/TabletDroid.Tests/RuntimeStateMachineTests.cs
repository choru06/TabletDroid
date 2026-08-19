using TabletDroid.Core.Models;
using TabletDroid.Runtime;
using Xunit;

namespace TabletDroid.Tests;

public class RuntimeStateMachineTests
{
    [Fact]
    public void ValidTransitions_Succeed()
    {
        var sm = new RuntimeStateMachine();
        Assert.Equal(RuntimeState.Stopped, sm.CurrentState);

        Assert.True(sm.TransitionTo(RuntimeState.Starting));
        Assert.True(sm.TransitionTo(RuntimeState.Booting));
        Assert.True(sm.TransitionTo(RuntimeState.Ready));
        Assert.True(sm.TransitionTo(RuntimeState.Suspended));
        Assert.True(sm.TransitionTo(RuntimeState.Ready));
        Assert.True(sm.TransitionTo(RuntimeState.Stopping));
        Assert.True(sm.TransitionTo(RuntimeState.Stopped));
    }

    [Fact]
    public void InvalidTransition_Fails()
    {
        var sm = new RuntimeStateMachine();
        Assert.Equal(RuntimeState.Stopped, sm.CurrentState);

        // Stopped -> Ready 직접 전이는 불허
        Assert.False(sm.TransitionTo(RuntimeState.Ready));
        Assert.Equal(RuntimeState.Stopped, sm.CurrentState);
    }
}
