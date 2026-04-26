public class Demo {
  static int n = 5;

  public static void main(String[] args) {
    int[] a = new int[n];

    int i = 0;
    while (i < n) {
      a[i] = i * 2;
      i = i + 1;
    }

    i = 0;
    while (i < n) {
      System.out.println(a[i]);
      i = i + 1;
    }

    int x = 10;
    if (x > 5) {
      System.out.println(x);
    } else {
      System.out.println(0);
    }
  }
}