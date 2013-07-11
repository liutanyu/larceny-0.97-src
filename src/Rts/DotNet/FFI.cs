using System;
using System.Reflection;
using System.Reflection.Emit;
using Scheme.RT;
using Scheme.Rep;


#if HAS_WINDOWS_FORMS
using System.Windows.Forms;
#endif

namespace Scheme.RT
{

#if HAS_WINDOWS_FORMS
  // Why is this here?  Can't think of a better place.
  // This wrapper is for the callback from the Windows message pump
  // which for some reason is not a delegate like every other callback.

    public class FFI_message_filter : IMessageFilter
    {
        Procedure scheme_filter;

        public FFI_message_filter (Procedure _scheme_filter)
        {
            this.scheme_filter = _scheme_filter;
        }

        public bool PreFilterMessage (ref Message m)
        {
            return Call.callback (scheme_filter, Factory.makeForeignBox (m))
                != Factory.False;
        }
    }
#endif

    public class FFI
    {

        // Public Constants

        public const bool TRUE = true;
        public const bool FALSE = false;
        public const object NULL = null;

        public static void ffi_syscall()
        {
            try
            {
                SObject scode = Reg.Register2;
                ffi_syscall_main(((SFixnum)scode).value);
            }
            catch (Exception e)
            {
                Exn.error("exception in ffi: " + e.ToString());
            }
        }

        private static void ffi_syscall_main(int code)
        {

            // SObject arg1 = Reg.Register3;
            // SObject arg2 = Reg.Register4;
            // SObject arg3 = Reg.Register5;
            // SObject arg4 = Reg.Register6;
            switch (code)
            {

                case 0:  // clr-version
                    // Return a list of integers indicating the version
                    // of the CLR runtime.
                    {
                        Version v = Environment.Version;
                        // return a list of 2, 3, or 4 elements
                        Reg.Result =
                            Factory.makePair
                             (Factory.makeNumber(v.Major),
                              Factory.makePair
                               (Factory.makeNumber(v.Minor),
                                (v.Build == -1)
                                ? (SObject)Factory.Null
                                : (SObject)
                                  Factory.makePair
                                   (Factory.makeNumber(v.Build),
                                    (v.Revision == -1)
                                    ? (SObject)Factory.Null
                                    : (SObject)
                                      Factory.makePair
                                       (Factory.makeNumber(v.Revision),
                                        Factory.Null))));
                        return;
                    }

                case 1: // ffi version
                    // Return a list of integers indicating the version of
                    // this FFI.
                    {
                        // Should actually do real versioning here.
                        Reg.Result =
                            Factory.makePair
                             (Factory.makeNumber(0),
                              Factory.makePair(Factory.makeNumber(0),
                                               Factory.Null));
                        return;
                    }

                case 2: // foreign?
                    // Return True iff argument is a ForeignBox wrapper.
                    {
                        // SObject arg1 = Reg.Register3;
                        // SObject arg2 = Reg.Register4;
                        // SObject arg3 = Reg.Register5;
                        // SObject arg4 = Reg.Register6;
                        Reg.Result
                            = (Reg.Register3 is ForeignBox)
                              ? Factory.True : Factory.False;
                        return;
                    }

                case 3: // to-string
                    {
                        SObject arg1 = Reg.Register3;
                        object val = ((ForeignBox)arg1).value;
                        Reg.Result
                            = Factory.makeUString((val == null)
                                                  ? "null" : val.ToString());
                        return;
                    }

                case 4: // object-type
                    {
                        SObject arg1 = Reg.Register3;
                        Reg.Result
                            = Factory.makeForeignBox
                               (((ForeignBox)arg1).value.GetType());
                        return;
                    }

                case 5: // isa?
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        object obj = ((ForeignBox)arg1).value;
                        Type type = (Type)((ForeignBox)arg2).value;
                        Reg.Result
                            = type.IsInstanceOfType(obj)
                              ? Factory.True : Factory.False;
                        return;
                    }

                case 6: // foreign-eq?
                    {
                        // this is a mess and should be rewritten!  ~jrm

                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        // SObject arg3 = Reg.Register5;
                        // SObject arg4 = Reg.Register6;
                        if (arg1 == arg2)
                        {
                            Reg.Result = Factory.True;
                        }
                        else if (arg1 is ForeignBox)
                        {
                            if (arg2 is ForeignBox)
                            {
                                // We can't use the Equals method on null
                                // objects, so we have to test for those
                                // first.

                                if (((ForeignBox)arg1).value == null)
                                {
                                    Reg.Result
                                        = (((ForeignBox)arg2).value == null)
                                          ? Factory.True
                                          : Factory.False;
                                }
                                else if (((ForeignBox)arg2).value == null)
                                {
                                    Reg.Result = Factory.False;
                                }
                                else
                                {
                                    Reg.Result
                                        = ((((ForeignBox)arg1).value)
                                           .Equals(((ForeignBox)arg2).value))
                                          ? Factory.True
                                          : Factory.False;
                                }
                            }
                            else if (arg2 is SFixnum)
                            {
                                Reg.Result = Factory.False;
                            }
                            else if (arg2 is SImmediate)
                            {
                                Reg.Result = Factory.False;
                            }
                            else
                                Exn.error("cannot unwrap foreign argument");
                        }
                        else if (arg1 is SFixnum)
                        {
                            if (arg2 is SFixnum)
                            {
                                Reg.Result
                                    = ((((ForeignBox)arg1).value)
                                       == (((ForeignBox)arg2).value))
                                      ? Factory.True
                                      : Factory.False;
                            }
                            else if (arg2 is ForeignBox)
                            {
                                Reg.Result = Factory.False;
                            }
                            else if (arg2 is SImmediate)
                            {
                                Reg.Result = Factory.False;
                            }
                            else
                                Exn.error("cannot unwrap foreign argument");
                        }

                        else if (arg1 is SImmediate)
                        {
                            if (arg2 is SImmediate)
                            {
                                Reg.Result = Factory.False;
                            }
                            else if (arg2 is ForeignBox)
                            {
                                Reg.Result = Factory.False;
                            }
                            else if (arg2 is SFixnum)
                            {
                                Reg.Result = Factory.False;
                            }
                            else
                                Exn.error("cannot unwrap foreign argument");
                        }
                        else
                            Exn.error("cannot unwrap foreign argument");
                        return;
                    }

                case 7: // get type
                    {
                        // SObject arg1 = Reg.Register3;
                        // string name = ((SByteVL)arg1).asString();
                        // case insensitive lookup
                        Type ft = Type.GetType(((SByteVL)(Reg.Register3))
                                               .asString(), false, true);
                        // Return #F if not found.
                        Reg.Result = (ft == null)
                                     ? Factory.False
                                     : Factory.makeForeignBox(ft);
                        return;
                    }

                // return the reflected field-info object associated with
                // a named field, or #F if not found

                case 8: // get field
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        FieldInfo fi = ((Type)((ForeignBox)arg1).value)
                                       .GetField(((SByteVL)arg2).asString());
                        Reg.Result = (fi == null)
                                     ? Factory.False
                                     : Factory.makeForeignBox(fi);
                        return;
                    }

                // return the reflected constructor
                // #F if not found

                case 9: // get-constructor
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject[] typev = ((SVL)arg2).elements;
                        Type[] types = new Type[typev.Length];
                        for (int i = 0; i < types.Length; ++i)
                        {
                            types[i] = (Type)((ForeignBox)typev[i]).value;
                        }
                        ConstructorInfo ci = ((Type)((ForeignBox)arg1).value)
                                             .GetConstructor(types);
                        Reg.Result = (ci == null)
                                     ? Factory.False
                                     : Factory.makeForeignBox(ci);
                        return;
                    }

                case 10: // get method
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject[] typev = ((SVL)arg3).elements;
                        Type[] types = new Type[typev.Length];
                        for (int i = 0; i < types.Length; ++i)
                        {
                            types[i] = (Type)((ForeignBox)typev[i]).value;
                        }
                        MethodInfo mi = ((Type)((ForeignBox)arg1).value)
                                        .GetMethod(((SByteVL)arg2).asString(),
                                                   types);
                        Reg.Result = (mi == null)
                                     ? Factory.False
                                     : Factory.makeForeignBox(mi);
                        return;
                    }

                case 11: // get property
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject[] typev = ((SVL)arg3).elements;
                        Type[] types = new Type[typev.Length];
                        for (int i = 0; i < types.Length; ++i)
                        {
                            types[i] = (Type)((ForeignBox)typev[i]).value;
                        }
                        PropertyInfo
                            pi = ((Type)((ForeignBox)arg1).value)
                                 .GetProperty(((SByteVL)arg2).asString(),
                                              types);
                        Reg.Result = (pi == null)
                                     ? Factory.False
                                     : Factory.makeForeignBox(pi);
                        return;
                    }

                case 12: // field-ref
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        FieldInfo fi = (FieldInfo)((ForeignBox)arg1).value;
                        try
                        {
                            Reg.Result
                                = Factory.makeForeignBox
                                   (fi.GetValue(fi.IsStatic
                                                ? null
                                                : ((ForeignBox)arg2).value));
                            return;
                        }
                        catch (Exception e)
                        {
                            Exn.error("ffi:field-get: " + e);
                            return;
                        }
                    }

                case 13: // field-set!
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        FieldInfo fi = (FieldInfo)((ForeignBox)arg1).value;
                        try
                        {
                            fi.SetValue(fi.IsStatic
                                            ? null
                                            : ((ForeignBox)arg2).value,
                                        ((ForeignBox)arg3).value);
                            Reg.Result = Factory.Unspecified;
                            return;
                        }
                        catch (Exception e)
                        {
                            Exn.error("ffi:field-set: " + e);
                            return;
                        }
                    }

                case 14: // invoke constructor
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        ConstructorInfo ci
                            = (ConstructorInfo)((ForeignBox)arg1).value;
                        SObject[] sargv = ((SVL)arg2).elements;
                        object[] args = new object[sargv.Length];
                        for (int i = 0; i < args.Length; ++i)
                        {
                            args[i] = ((ForeignBox)(sargv[i])).value;
                        }
                        try
                        {
                            Reg.Result
                                = Factory.makeForeignBox(ci.Invoke(args));
                            return;
                        }
                        catch (Exception e)
                        {
                            Exn.error("ffi:invoke-constructor: " + e);
                            return;
                        }
                    }

                case 15: // invoke method
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        MethodInfo mi = (MethodInfo)((ForeignBox)arg1).value;
                        SObject[] sargv = ((SVL)arg3).elements;
                        object[] args = new object[sargv.Length];
                        for (int i = 0; i < args.Length; i++)
                            args[i] = ((ForeignBox)(sargv[i])).value;

                        // I wonder if this version is better?
                        //    int i = 0;
                        //    foreach (SObject sarg in sargv)
                        //      args [i++] = ((ForeignBox) sarg).value;

                        object result;
                        try
                        {
                            result = mi.Invoke(mi.IsStatic
                                                   ? null
                                                   : ((ForeignBox)arg2).value,
                                               args);
                        }
                        catch (Exception e)
                        {
                            Exn.error
                             ("ffi:invoke: error in foreign function: " + e);
                            return;
                        }

                        Reg.Result = Factory.makeForeignBox(result);
                        return;
                    }

                case 16: // property-ref
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject[] sargv = ((SVL)arg3).elements;
                        object[] args = new object[sargv.Length];
                        for (int i = 0; i < args.Length; ++i)
                            args[i] = ((ForeignBox)(sargv[i])).value;
                        object result;
                        try
                        {
                            result
                                = ((PropertyInfo)((ForeignBox)arg1).value)
                                  .GetValue(((ForeignBox)arg2).value, args);
                        }
                        catch (Exception e)
                        {
                            Exn.error
                             ("ffi:invoke: error in foreign function: " + e);
                            return;
                        }
                        Reg.Result = Factory.makeForeignBox(result);
                        return;
                    }

                case 17: // property-set
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject arg4 = Reg.Register6;
                        SObject[] sargv = ((SVL)arg4).elements;
                        object[] args = new object[sargv.Length];
                        for (int i = 0; i < args.Length; ++i)
                            args[i] = ((ForeignBox)(sargv[i])).value;
                        try
                        {
                            ((PropertyInfo)
                             ((ForeignBox)arg1).value)
                            .SetValue(((ForeignBox)arg2).value,
                                      ((ForeignBox)arg3).value,
                                      args);
                        }
                        catch (Exception e)
                        {
                            Exn.error
                             ("ffi:invoke: error in foreign function: " + e);
                            return;
                        }
                        Reg.Result = Factory.Unspecified;
                        return;
                    }

                case 18: // array ref
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        Reg.Result
                            = Factory.makeForeignBox
                               (((Array)
                                 ((ForeignBox)arg1).value)
                                .GetValue(((SFixnum)arg2).value));
                        return;
                    }

                case 19: // datum2foreign
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        Reg.Result = datum2foreign(((SFixnum)arg1).value, arg2);
                        return;
                    }

                case 20: // foreign2datum
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        Reg.Result = foreign2datum(((SFixnum)arg1).value, arg2);
                        return;
                    }

                case 21: // get-property-value-boolean
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject[] sargv = ((SVL)arg3).elements;
                        object[] args = new object[sargv.Length];
                        for (int i = 0; i < args.Length; ++i)
                            args[i] = ((ForeignBox)(sargv[i])).value;
                        object result;
                        try
                        {
                            result
                                = ((PropertyInfo)
                                   ((ForeignBox)arg1).value)
                                  .GetValue(((ForeignBox)arg2).value, args);
                        }
                        catch (Exception e)
                        {
                            Exn.error
                             ("ffi:invoke: error in foreign function: " + e);
                            return;
                        }
                        Reg.Result
                            = Factory.makeBoolean((bool)result != false);
                        return;
                    }
                case 22: // get-property-value-int
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject[] sargv = ((SVL)arg3).elements;
                        object[] args = new object[sargv.Length];
                        for (int i = 0; i < args.Length; ++i)
                            args[i] = ((ForeignBox)(sargv[i])).value;
                        object result;
                        try
                        {
                            result
                                = ((PropertyInfo)
                                   ((ForeignBox)arg1).value)
                                  .GetValue(((ForeignBox)arg2).value, args);
                        }
                        catch (Exception e)
                        {
                            Exn.error
                             ("ffi:invoke: error in foreign function: " + e);
                            return;
                        }
                        Reg.Result = Factory.makeNumber((int)result);
                        return;
                    }

#if HAS_WINDOWS_FORMS
            case 23: // get-property-value-native-window
            {
                SObject arg1 = Reg.Register3;
                SObject arg2 = Reg.Register4;
                SObject arg3 = Reg.Register5;
                SObject[] sargv = ((SVL) arg3).elements;
                object[] args = new object [sargv.Length];
                for (int i = 0; i < args.Length; ++i)
                    args[i] = ((ForeignBox)(sargv[i])).value;
                object result;
                try {
                    result
                        = ((PropertyInfo)
                           ((ForeignBox) arg1).value)
                          .GetValue (((ForeignBox) arg2).value, args);
                    }
                catch (Exception e) {
                    Exn.error ("ffi:invoke: error in foreign function: " + e);
                    return;
                   }
                Reg.Result
                    = Factory.makeForeignBox
                       (System.Windows.Forms.NativeWindow.FromHandle
                        ((IntPtr)result));
                return;
            }
#else
                case 23:
                    {
                        Exn.error("ffi:invoke property-value as native-window not supported in this version");
                        return;
                    }
#endif

                case 24: // get-property-value-intptr
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject[] sargv = ((SVL)arg3).elements;
                        object[] args = new object[sargv.Length];
                        for (int i = 0; i < args.Length; ++i)
                            args[i] = ((ForeignBox)(sargv[i])).value;
                        object result;
                        try
                        {
                            result
                                = ((PropertyInfo)
                                   ((ForeignBox)arg1).value)
                                  .GetValue(((ForeignBox)arg2).value, args);
                        }
                        catch (Exception e)
                        {
                            Exn.error
                             ("ffi:invoke: error in foreign function: " + e);
                            return;
                        }
                        Reg.Result = Factory.makeNumber((int)((IntPtr)result));
                        return;
                    }

                case 25: // add-event-handler
                    {
                        SObject arg1 = Reg.Register3; // publisher
                        SObject arg2 = Reg.Register4; // event-name
                        SObject arg3 = Reg.Register5; // procedure (handler)

                        try
                        {
                            // cast arguments to appropriate types
                            object publisher = ((ForeignBox)arg1).value;
                            string eventName = ((SByteVL)arg2).asString();
                            Procedure proc
                                = (Procedure)(((ForeignBox)arg3).value);
                            
                            // get information about the event
                            EventInfo ei
                                = publisher.GetType().GetEvent(eventName);

                            // add handler for the event
                            ei.AddEventHandler(publisher,
                                               proc.makeEventHandler(ei));
                        }
                        catch (Exception e)
                        {
                            Exn.error("ffi:add-event-handler: error in foreign function: " + e);
                            return;
                        }

                        // return true if we successfully added handler
                        Reg.Result = Factory.True; 
                        return;
                    }
                case 26: // load-assembly(name, version, culture, publickey)
                    {
                        SObject arg1 = Reg.Register3;
                        SObject arg2 = Reg.Register4;
                        SObject arg3 = Reg.Register5;
                        SObject arg4 = Reg.Register6;
                        string name =      ((SByteVL)arg1).asString();
                        string version =   ((SByteVL)arg2).asString();
                        string culture =   ((SByteVL)arg3).asString();
                        string publickey = ((SByteVL)arg4).asString();
                        Load.LoadAssembly(name, version, culture, publickey);
                        Reg.Result = Factory.Unspecified;
                        return;
                    }
            }

            Exn.error("bad ffi syscall code");
            return;
        }

        private static SObject wrapF(object o)
        {
            if (o is Int32 && SFixnum.inFixnumRange((int)o))
            {
                return Factory.makeFixnum((int)o);
            }
            else
            {
                return Factory.makeForeignBox(o);
            }
        }
        private static object unwrapF(SObject s)
        {
            if (s is SFixnum)
            {
                return ((SFixnum)s).value;
            }
            else if (s is ForeignBox)
            {
                return ((ForeignBox)s).value;
            }
            else
            {
                Exn.error("cannot unwrap foreign argument");
                return Factory.Impossible;
            }
        }

        private static SObject datum2foreign(int conversion, SObject obj)
        {
            // datum->foreign : conversion value -> F

            // Always returns a foreign box.  Contents of the box is controlled
            // by the conversion switch.
            switch (conversion)
            {
                // No conversion.  Scheme object is placed in the box.
                case 0:
                    {
                        return Factory.makeForeignBox(obj);
                    }

                // String.
                case 1:
                    {
                        return Factory.makeForeignBox
                                (((SByteVL)obj).asString());
                    }

                // various integer forms
                case 2:
                    {
                        return Factory.makeForeignBox
                                ((Byte)((SFixnum)obj).value);
                    }

                case 3:
                    {
                        return Factory.makeForeignBox
                                ((UInt16)((SFixnum)obj).value);
                    }

                case 4:
                    {
                        return Factory.makeForeignBox
                                ((UInt32)((SFixnum)obj).value);
                    }

                case 5:
                    {
                        return Factory.makeForeignBox
                                ((SByte)((SFixnum)obj).value);
                    }

                case 6:
                    {
                        return Factory.makeForeignBox
                                ((Int16)((SFixnum)obj).value);
                    }

                case 7:
                    {
                        return Factory.makeForeignBox
                                ((Int32)((SFixnum)obj).value);
                    }

                case 8: // message filter
                    {
#if HAS_WINDOWS_FORMS
                    return Factory.makeForeignBox
                            (new FFI_message_filter ((Procedure) obj));
#else
                        Exn.error("datum->foreign (message_filter) not supported in this version");
                        return Factory.Impossible;
#endif
                    }

                case 10: // single precision float
                    {
                        return Factory.makeForeignBox
                                ((float)((SByteVL)obj).unsafeAsDouble(0));
                    }

                case 11: //double precision float
                    {
                        return Factory.makeForeignBox
                                ((double)((SByteVL)obj).unsafeAsDouble(0));
                    }

                case 12: // character
                    {
                        return Factory.makeForeignBox((Char)((SChar)obj).val);
                    }

                case 13: // bytevector-like
                    {
                        object copy = ((SByteVL)obj).elements.Clone();
                        return Factory.makeForeignBox((byte[])copy);
                    }

#if NEVER

                case 0: // object
                {
                    if (obj is SFixnum || obj is ForeignBox) {
                        return obj;
                    } else {
                        Exn.error ("datum->foreign (object) expected F");
                        return Factory.Impossible;
                    }
                }
                case 1: // schemeobject
                {
                    return Factory.makeForeignBox (obj);
                }
                case 2: // string
                {
                    if (obj is SByteVL) {
                        string value = ((SByteVL)obj).asString();
                        return Factory.makeForeignBox (value);
                    } else {
                        Exn.error ("datum->foreign (string) expected string");
                        return Factory.Impossible;
                    }
                }
                case 3: // symbol
                {
                    Exn.error
                     ("datum->foreign (symbol) not implemented in runtime");
                    return Factory.Impossible;
                }
                case 4: // bytes
                {
                    if (obj is SByteVL) {
                        return Factory.makeForeignBox
                                (((SByteVL)obj).elements);
                    } else {
                        Exn.error
                         ("datum->foreign (bytes) expected bytevector");
                        return Factory.Impossible;
                    }
                }
                case 5: // int
                {
                    if (obj is SFixnum) {
                        return obj;
                    } else if (obj.isBignum()) {
                        SByteVL n = (SByteVL)obj;
                        if (Number.getBignumLength(n) == 1) {
                            uint magn = (uint)(Number.bignumRef(n, 1) << 16)
                                      + (uint)Number.bignumRef(n, 0);
                            int val = magn;
                            if (! (Number.getBignumSign(n)))
                                magn = - magn;
                            return Factory.makeForeignBox (val);
                        }
                    }
                    Exn.error("datum->foreign (int) expected small integer");
                    return Factory.Impossible;
                }
                case 6: // float
                {
                    if (obj.isFlonum()) {
                        double value = ((SByteVL)obj).unsafeAsDouble(0);
                        return Factory.makeForeignBox ((float)value);
                    } else {
                        Exn.error("datum->foreign (float) expected flonum");
                        return Factory.Impossible;
                    }
                }
                case 7: // double
                {
                    if (obj.isFlonum()) {
                        double value = ((SByteVL)obj).unsafeAsDouble(0);
                        return Factory.makeForeignBox (value);
                    } else {
                        Exn.error("datum->foreign (float) expected flonum");
                        return Factory.Impossible;
                    }
                }
                case 8: // void
                {
                    Exn.error("datum->foreign (void) not allowed");
                    return Factory.Impossible;
                }
                case 9: // message filter
                {
                    if (obj is Procedure)
                        return Factory.makeForeignBox
                                (new FFI_message_filter ((Procedure) obj));
                    else {
                        Exn.error
                         ("datum->foreign (message filter) expected procedure");
                        return Factory.Impossible;
                        }
                }
#endif

            }
            Exn.error("datum->foreign: unknown conversion");
            return Factory.Impossible;
        }

        private static SObject foreign2datum(int conversion, SObject obj)
        {
            // foreign->datum : conversion F -> value
            object value;
            if (obj is ForeignBox)
            {
                value = ((ForeignBox)obj).value;
            }
            else if (obj is SFixnum)
            {
                value = ((SFixnum)obj).value;
            }
            else
            {
                Exn.error
                 ("foreign->datum: argument is not foreign-box or fixnum");
                return Factory.Impossible;
            }

            switch (conversion)
            {
                case 0:
                    { // object
                        return obj;
                    }
                case 1:
                    { // schemeobject
                        if (value is SObject)
                        {
                            return (SObject)value;
                        }
                        else
                        {
                            Exn.error("foreign->datum (schemeobject): not a scheme value");
                            return Factory.Impossible;
                        }
                    }
                case 2:
                    { // string
                        if (value is string)
                        {
                            return Factory.makeUString((string)value);
                        }
                        else
                        {
                            Exn.error("foreign->datum (string): not a string");
                            return Factory.Impossible;
                        }
                    }
                case 3:
                    { // symbol
                        Exn.error
                         ("foreign->datum (symbol): not handled by runtime");
                        return Factory.Impossible;
                    }
                case 4:
                    { // bytes
                        if (value is byte[])
                        {
                            return Factory.makeByteVector
                              ((byte[])((byte[])value).Clone());
                        }
                        else
                        {
                            Exn.error("foreign->datum (bytes): not byte[]");
                            return Factory.Impossible;
                        }
                    }
                case 5:
                    { // int
                        if (value is Enum)
                        {
                            Type enum_type = value.GetType();
                            Type underlying_type
                                = Enum.GetUnderlyingType(enum_type);
                            if (underlying_type == typeof(Byte))
                                return Factory.makeFixnum((byte)value);
                            if (underlying_type == typeof(SByte))
                                return Factory.makeFixnum((sbyte)value);
                            if (underlying_type == typeof(char))
                                return Factory.makeFixnum((char)value);
                            if (underlying_type == typeof(short))
                                return Factory.makeFixnum((short)value);
                            if (underlying_type == typeof(int))
                                return Factory.makeNumber((int)value);
                            if (underlying_type == typeof(long))
                                return Factory.makeNumber((long)value);
                            if (underlying_type == typeof(ushort))
                                return Factory.makeFixnum((ushort)value);
                            if (underlying_type == typeof(uint))
                                return Factory.makeNumber((uint)value);
                            if (underlying_type == typeof(ulong))
                                return Factory.makeNumber((ulong)value);
                            Exn.error("foreign->datum (enum): not an integer");
                            return Factory.Impossible;
                        }
                        if (value is Byte)
                            return Factory.makeFixnum((byte)value);
                        if (value is SByte)
                            return Factory.makeFixnum((sbyte)value);
                        if (value is char)
                            return Factory.makeFixnum((char)value);
                        if (value is short)
                            return Factory.makeFixnum((short)value);
                        if (value is int)
                            return Factory.makeNumber((int)value);
                        if (value is long)
                            return Factory.makeNumber((long)value);
                        if (value is ushort)
                            return Factory.makeFixnum((ushort)value);
                        if (value is uint)
                            return Factory.makeNumber((uint)value);
                        if (value is ulong)
                            return Factory.makeNumber((ulong)value);

                        Exn.error("foreign->datum (int): not an integer");
                        return Factory.Impossible;
                    }
                case 6:
                    { // float
                        if (value is float)
                        {
                            return Factory.makeFlonum((float)value);
                        }
                        else
                        {
                            Exn.error("foreign->datum (float): not a float");
                            return Factory.Impossible;
                        }
                    }
                case 7:
                    { // double
                        if (value is double)
                        {
                            return Factory.makeFlonum((double)value);
                        }
                        else
                        {
                            Exn.error("foreign->datum (double): not a double");
                            return Factory.Impossible;
                        }
                    }
                case 8:
                    { // void
                        return Factory.Unspecified;
                    }
            }
            Exn.error("foreign->datum: unknown conversion");
            return Factory.Impossible;
        }
    }
}
