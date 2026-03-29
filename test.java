// Comprehensive subset test for the transpiler (Java → C++).
public class Test {
  public static void main(String[] args) {
    int a = 7;
    int b = 3;
    boolean flag = true;

    if (a > b && flag) {
      System.out.println(a - b);
    } else {
      System.out.println(0);
    }

    int sum = 0;
    for (int i = 0; i < 4; i++) {
      sum += i;
    }
    System.out.println(sum);

    String msg = "ok";
    System.out.println(msg);

    int x = 10;
    while (x > 7) {
      x--;
    }
    System.out.println(x);
  }
}
