/**
 * @description Test Class to retrieve a record from the test Network Member table using passed in Username and Network Id.
 * @author: Jamie Lowe
 */
@isTest
private class RetrieveNetworkMembersTest {
    
    @isTest
    private static void validateUsernameTest() {
        List<NetworkMember> userList = RetrieveNetworkMembers.validateUsername('test@mail.com', '123');
        System.assertEquals(0, userList.size(), 'Username is valid');
    }
}