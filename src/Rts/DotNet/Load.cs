using System;
using System.IO;
using System.Reflection;
using Scheme.RT;
using Scheme.Rep;
using System.Text.RegularExpressions;
using System.Diagnostics;

namespace Scheme.RT {

public class Load {
  public const bool reportResult = false;
  public static string[] librarySearchPaths;

  static Load()
  {
    string p = Environment.GetEnvironmentVariable ("LARCENYCS_LIB_PATH");
    if (p == null) {
      librarySearchPaths = new string[0];
      return;
    }
    Regex r = new Regex ("([^\";]|(\"[^\"]*\"))+");
    MatchCollection mc = r.Matches (p);
    string[] ms = new string[mc.Count];
    for (int i = 0; i < ms.Length; ++i) {
      ms[i] = mc[i].Value;
      // System.Console.WriteLine ("librarySearchPaths... added {0}", ms[i]);
    }
    librarySearchPaths = ms;
  }

  public static string nameToAssemblyName (string name)
  {
    if (Regex.IsMatch (name, ".exe", RegexOptions.IgnoreCase)) {
      return name;
    }
    else {
      return name + ".EXE";
    }
  }

  /* Convenience method so that Scheme code can get away with using
     strings rather than Version objects and byte arrays and so on.
     
     Example usage:
     LoadAssembly("System.Windows.Forms", "2.0.0.0", "", "b77a5c561934e089");
     (you can find such info via the gacutil program)
  */

  public static void LoadAssembly(string name, 
                                  string version, // "maj.min.build.revision"
                                  string culture, 
                                  string publickey)
  {
    System.Reflection.AssemblyName n = new System.Reflection.AssemblyName();
    n.Name = name;
    n.Version = new System.Version(version);
    n.CultureInfo = new System.Globalization.CultureInfo(culture);
    n.SetPublicKeyToken( ToByteArray(publickey) );
    // Console.WriteLine("Attempting to load: {0}", n.FullName);
    System.Reflection.Assembly.Load(n);
  }

  private static byte[] ToByteArray(String HexString) {
    int NumberChars = HexString.Length;
    byte[] bytes = new byte[NumberChars / 2];
    for (int i = 0; i < NumberChars; i += 2) {
      bytes[i / 2] = Convert.ToByte(HexString.Substring(i, 2), 16);
    }
    return bytes;
  }

  public static Assembly findAssembly (string basename)
  {
    string name = nameToAssemblyName (basename);
    if (File.Exists (name)) {
      return Assembly.LoadFrom (name);
    }
    foreach (string path in librarySearchPaths) {
      string fullname = Path.Combine (path, name);
      if (File.Exists (fullname)) {
        return Assembly.LoadFrom (fullname);
      }
    }
    return null;
  }

  public static void InitializePerformanceCounters ()
  {
#if HAS_PERFORMANCE_COUNTERS
    if (PerformanceCounterCategory.Exists ("Scheme")) {
      // If the counters exist, get a hold of them.
      // If not, no big deal.
      try {
        Call.applySetupCounter
          = new PerformanceCounter ("Scheme", "Apply Setup", false);
      } catch (Exception) {}
      try {
        Call.bounceCounter
          = new PerformanceCounter ("Scheme", "Trampoline Bounces", false);
      } catch (Exception) {}
      try {
        Call.schemeCallCounter
          = new PerformanceCounter ("Scheme", "Scheme Call Exceptions", false);
      } catch (Exception) {}
      try {
        Call.millicodeSupportCallCounter
          = new PerformanceCounter ("Scheme",
                                    "Millicode Support Calls",
                                    false);
      } catch (Exception) {}
      try {
        Cont.stackFlushCounter
          = new PerformanceCounter ("Scheme", "Stack Flushes", false);
      } catch (Exception) {}
      try {
        Cont.stackReloadCounter
          = new PerformanceCounter ("Scheme", "Stack Reloads", false);
      } catch (Exception) {}
    }
#endif
  }

  public static
  bool test_checked()
  {
    int x = Int32.MaxValue;
    try {
      for (int i = 0; i < 10; i++) x += i;
      return false;
    }
    catch (Exception) {
      return true;
    }
  }

  // MainHelper takes the argument vector, executes the body of the caller's
  // assembly (should be the assembly corresponding to the compiled scheme
  // code) and then executes the "go" procedure, if available.

  public static void MainHelper (string[] args)
  {
    Console.WriteLine ("CommonLarceny");
    Console.WriteLine ("CLR, Version={0}", System.Environment.Version);
    Console.WriteLine ("{0}",
                       System.Reflection.Assembly.GetExecutingAssembly());
    Console.WriteLine ("{0}", System.Reflection.Assembly.GetCallingAssembly());
    Console.WriteLine ("");

    Debug.Listeners.Add (new TextWriterTraceListener (Console.Out));
    //  Debug.WriteLine ("CLR Version:  {0}", System.Environment.Version);
    Debug.WriteLine ("DEBUG version of Scheme runtime.");
    Debug.WriteLine (test_checked()
                     ? "CHECKED arithmetic"
                     : "UNCHECKED arithmetic");

    { // Establish invariant that LARCENY_ROOT has been set before we
      // invoke (interactive-entry-point ...)

      string lar_root = Environment.GetEnvironmentVariable( "LARCENY_ROOT" );
      if (lar_root == null) {

        Type[] argtypes = { typeof(string), typeof(string) };
        MethodInfo method;

        string location = Assembly.GetCallingAssembly().Location;
        lar_root = System.IO.Path.GetDirectoryName(location);

        // By reflection:
        // Environment.SetEnvironmentVariable("LARCENY_ROOT", lar_root);

        try {
          method = typeof(Environment).GetMethod("SetEnvironmentVariable",
                                                 argtypes);
          method.Invoke(null, new Object[]{"LARCENY_ROOT", lar_root});
        }
        catch (Exception e) {
          throw new Exception("Couldn't set LARCENY_ROOT; please "
                              + "set it and try again: ", e);
        }
      }
    }

    // Mono throws a not implemented exception here.

    try {
        InitializePerformanceCounters();
    }  catch (Exception) {};
    Debug.WriteLine ("Initializing fixnum pool.");
    SFixnum.Initialize();
    Debug.WriteLine ("Initializing immediates.");
    SImmediate.Initialize();
    Debug.WriteLine ("Initializing char pool.");
    SChar.Initialize();
    Debug.WriteLine ("Initializing registers.");
    Reg.Initialize (Assembly.GetCallingAssembly());
    Cont.Initialize();

    bool keepRunning = handleAssembly (Reg.programAssembly);
    if (keepRunning) handleGo (args);
  }

  public static bool handleAssembly (Assembly asm)
  {
    bool keepRunning = true;
    Timer timer = new Timer();
    if (asm == null) {
      Exn.msg.WriteLine ("Module {0} failed load", asm);
      return keepRunning;
    }

    // Exn.msg.WriteLine ("Executing IL Module: {0}", asm);

    Type manifest = asm.GetType ("SchemeManifest");
    if (manifest != null) {
      keepRunning = handleManifest (manifest);
    }
    return keepRunning;
  }

  public static bool handleManifest (Type manifest)
  {
    bool keepRunning = true;
    MethodInfo debugInfo = manifest.GetMethod ("DebugInfo");
    if (debugInfo == null) {
      Exn.msg.WriteLine ("** warning: module does not provide debug info");
    }
    else {
      debugInfo.Invoke (null, new object[]{});
    }
    MethodInfo topLevel = manifest.GetMethod ("TopLevel");
    if (topLevel == null) {
      Exn.msg.WriteLine ("** error: cannot get TopLevel procedures");
      return keepRunning;
    }
    Procedure[] topLevelProcs
      = (Procedure[]) topLevel.Invoke (null, new object[]{});
    SObject[] noArgs = new SObject[] {};
    foreach (Procedure command in topLevelProcs) {
      if (keepRunning) {
        keepRunning = handleProcedure (command, noArgs);
      }
    }
    return keepRunning;
  }

  public static bool handleProcedure (Procedure command, SObject[] args)
  {
    bool keepRunning = true;
    bool errorOccurred = true;
    try {
      Reg.clearRegisters();
      for (int i = 0; i < args.Length; ++i) {
        Reg.setRegister (i + 1, args[i]);
      }
      Call.trampoline (command, args.Length);
      errorOccurred = false;
    }
    catch (SchemeExitException see) {
      keepRunning = false;
      errorOccurred = false;
      if (see.returnCode != 0) {
        // Exn.msg.WriteLine ("Machine exited with error code "
        //                    + see.returnCode);
        Exn.fullCoreDump();
        Environment.Exit(see.returnCode);
      }
    }
    finally {
      if (errorOccurred) Exn.fullCoreDump();
    }
    //            if (reportResult) {
    //                Exn.msg.WriteLine ("  {0}", Reg.Result);
    //            }
    return keepRunning;
  }

  public static void handleGo (string[] args)
  {
    Procedure go;
    try {
      go = (Procedure) Reg.globalValue ("go");
    }
    catch {
      Exn.msg.WriteLine ("Procedure go is not defined. Skipping.");
      return;
    }
    try {
      Procedure main = (Procedure) Reg.globalValue ("main");
    }
    catch {
      Exn.msg.WriteLine ("Procedure main is not defined. Not calling go.");
      return;
    }
    Debug.WriteLine ("Executing (go ...)");
    handleProcedure (go,
                     new SObject[] {Factory.stopSymbolInterning(),
                                    makeArgv (args)});
  }

  public static SObject makeArgv (string[] args)
  {
    SObject[] argv = new SObject[args.Length];
    for (int i = 0; i < args.Length; ++i) {
      argv[i] = Factory.makeAsciiByteVector (args[i]);
    }
    return Factory.makeVector (argv);
  }

  public static SObject findCode (string module, string ns, int id, int number)
  {
    // First look in programAssembly

    CodeVector cv = findCodeInAssembly (Reg.programAssembly, ns, number);
    if (cv != null) return cv;

    // Then look in external Assembly via module in name

    Assembly moduleAssembly;
    try {
      moduleAssembly = Assembly.LoadFrom (module + ".exe");
    }
    catch {
      try { 
        moduleAssembly = Assembly.LoadFrom (module + ".dll");
      }        
      catch {        
        Exn.error ("code not found (no EXE or DLL file): " + module);
        return Factory.Impossible;
      }
    }
    cv = findCodeInAssembly (moduleAssembly, ns, number);
    if (cv != null) return cv;
    Exn.error ("code not found: " + module + " " + ns + " " + number);
    return Factory.False;
  }

  public static
  CodeVector findCodeInAssembly (Assembly asm, string ns, int number)
  {
    if (asm == null) return null;
    Type t = asm.GetType (ns + ".Loader_" + number, false);
    if (t != null) {
      FieldInfo fi = t.GetField ("entrypoint");
      if (fi != null) {
        return (CodeVector)fi.GetValue (null);
      }
    }
    return null;
  }
}    // end class Load
}    // end namespace Scheme.RT
