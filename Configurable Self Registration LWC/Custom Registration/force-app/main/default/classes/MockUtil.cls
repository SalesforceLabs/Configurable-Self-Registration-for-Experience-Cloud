public class MockUtil {
    private MockUtil(){}

    public static MockProvider getInstance() {
        return new MockProvider();
    }
    
     public static Object createMock(Type typeToMock) {
        //Invoke the stub API and pass it our mock provider to create a mock class of typeToMock.
        return Test.createStub(typeToMock, MockUtil.getInstance());
    }
}