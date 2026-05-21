import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../data/auth_repository.dart';

import '../../../dashboard/presentation/screens/admin_dashboard.dart';
import '../../../dashboard/presentation/screens/trainer_dashboard.dart';
import '../../../dashboard/presentation/screens/school_dashboard.dart';
import '../../../dashboard/presentation/screens/student_dashboard.dart';

import 'signup_screen.dart';


class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}


class _LoginScreenState
    extends State<LoginScreen> {

  final _formKey =
      GlobalKey<FormState>();

  final _usernameController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _authRepo =
      AuthRepository();

  bool _loading = false;

  bool _obscurePassword =
      true;

  String? _error;

  @override
  void dispose() {

    _usernameController.dispose();

    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _handleLogin() async {

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {

      _loading = true;

      _error = null;

    });

    try {

      final result =
          await _authRepo.login(

        username:
            _usernameController.text
                .trim(),

        password:
            _passwordController.text,

      );

      if (result['success']
              ==
          true &&
          mounted) {

        final role =
            result['role'];

        final profile =
            result['profile'];

        Widget screen;

        switch (role
            .toLowerCase()) {

          case 'admin':

            screen =
                AdminDashboard(
              profile:
                  profile,
            );

            break;

          case 'trainer':

            screen =
                TrainerDashboard(
              profile:
                  profile,
            );

            break;

          case 'school':

            screen =
                SchoolDashboard(
              profile:
                  profile,
            );

            break;

          default:

            screen =
                StudentDashboard(
              profile:
                  profile,
            );
        }

        Navigator.pushReplacement(

          context,

          MaterialPageRoute(

            builder:
                (_) =>
                    screen,

          ),

        );
      }

    } catch (e) {

      setState(() {

        _error =
            e.toString();

      });

    }

    setState(() {

      _loading =
          false;

    });
  }

  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      backgroundColor:
          Colors.white,

      body: Center(

        child:
            SingleChildScrollView(

          padding:
              const EdgeInsets
                  .all(
            24,
          ),

          child:
              Container(

            width:
                420,

            padding:
                const EdgeInsets
                    .all(
              28,
            ),

            decoration:
                BoxDecoration(

              color:
                  Colors.white,

              borderRadius:
                  BorderRadius
                      .circular(
                16,
              ),

              boxShadow: [

                BoxShadow(

                  color: Colors
                      .black
                      .withOpacity(
                          0.06),

                  blurRadius:
                      20,

                )

              ],

            ),

            child:
                Form(

              key:
                  _formKey,

              child:
                  Column(

                children: [

                  const Icon(

                    LucideIcons
                        .graduationCap,

                    size:
                        50,

                    color:
                        Color(
                      0xFF2563EB,
                    ),

                  ),

                  const SizedBox(
                    height:
                        20,
                  ),

                  Text(

                    "Rovolo EdTech",

                    style:
                        GoogleFonts
                            .outfit(

                      fontSize:
                          28,

                      fontWeight:
                          FontWeight
                              .bold,

                    ),

                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  Text(

                    "Login to continue",

                    style:
                        GoogleFonts
                            .inter(),

                  ),

                  const SizedBox(
                    height:
                        20,
                  ),

                  if (_error !=
                      null)

                    Text(

                      _error!,

                      style:
                          const TextStyle(

                        color:
                            Colors.red,

                      ),

                    ),

                  const SizedBox(
                    height:
                        20,
                  ),

                  TextFormField(

                    controller:
                        _usernameController,

                    decoration:
                        const InputDecoration(

                      labelText:
                          "Username",

                    ),

                    validator:
                        (v) {

                      if (v ==
                              null ||
                          v.isEmpty) {

                        return "Required";
                      }

                      return null;
                    },

                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  TextFormField(

                    controller:
                        _passwordController,

                    obscureText:
                        _obscurePassword,

                    decoration:
                        InputDecoration(

                      labelText:
                          "Password",

                      suffixIcon:

                          IconButton(

                        onPressed:
                            () {

                          setState(
                              () {

                            _obscurePassword =
                                !_obscurePassword;

                          });

                        },

                        icon:
                            Icon(

                          _obscurePassword
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,

                        ),

                      ),

                    ),

                    validator:
                        (v) {

                      if (v ==
                              null ||
                          v.isEmpty) {

                        return "Required";
                      }

                      return null;

                    },

                  ),

                  const SizedBox(
                    height:
                        24,
                  ),

                  SizedBox(

                    width:
                        double
                            .infinity,

                    child:
                        ElevatedButton(

                      onPressed:
                          _loading
                              ? null
                              : _handleLogin,

                      child:
                          _loading

                              ? const CircularProgressIndicator()

                              : const Text(
                                  "Login",
                                ),

                    ),

                  ),

                  const SizedBox(
                    height:
                        20,
                  ),

                  Row(

                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,

                    children: [

                      const Text(
                        "No account? ",
                      ),

                      InkWell(

                        onTap:
                            () {

                          Navigator
                              .pushReplacement(

                            context,

                            MaterialPageRoute(

                              builder:
                                  (_) =>
                                      const SignupScreen(),

                            ),

                          );

                        },

                        child:
                            const Text(

                          "Sign Up",

                          style:
                              TextStyle(

                            color:
                                Color(
                              0xFF2563EB,
                            ),

                            fontWeight:
                                FontWeight.bold,

                          ),

                        ),

                      ),

                    ],

                  )

                ],

              ),

            ),

          ),

        ),

      ),

    );
  }
}