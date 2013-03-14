KIFLog2Unit
===========

Converts KIF output log messages to JUnit test results for using KIF in a continuous integration environment.

Tested and working with the Publish JUnit Test Result Report post-build action in Jenkins.

### Usage

1. Set `TEST_SUITE_NAME` to whatever you want your test suite to show up as in Jenkins
2. Save the script somewhere in your Jenkins user's PATH, and make it executable with `chmod +x KIFLog2JUnit.rb`
3. Build your KIF target with the Xcode build plugin/step
4. Run the app in the simulator (we use waxsim to launch it) and save the output to a file:
`waxsim -s 6.1 -f iphone -v ${WORKSPACE}/test-run.mov "${WORKSPACE}/build/KIFTests.app" > KIF-AutomationTests.out 2>&1
`
5. Process the file with the script:
 `KIFLog2JUnit.rb ${WORKSPACE}/KIF-AutomationTests.out`
6. Publish the xml file using the JUnit post-build publisher:

![](http://dl.dropbox.com/u/25940783/Screenshots/6t5t.png)
