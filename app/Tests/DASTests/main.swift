import DASCore
import Foundation

let t = TestRunner()
runCatalogTests(t)
runStatusTests(t)
runPlanningTests(t)
runPlumbingTests(t)
runCLITests(t)
runOutputTests(t)
exit(t.finish())
